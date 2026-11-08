import SwiftUI
import UIKit

struct IslandPose: Equatable {
    let width: CGFloat
    let height: CGFloat
    var history: CGFloat = 0

    static let composer = Self(width: 1, height: 100, history: 1)
    static let loading = Self(width: 0.78, height: 80)

    static func reminders(fontSize: CGFloat) -> Self {
        Self(width: 1, height: 204 + max(0, fontSize - 18) * 5)
    }

    func blend(to end: Self, amount: CGFloat) -> Self {
        Self(
            width: width + (end.width - width) * amount,
            height: height + (end.height - height) * amount,
            history: history + (end.history - history) * amount
        )
    }
}

/// Owns the presented geometry so a touch can interrupt the spring without a jump.
@MainActor @Observable
final class IslandMotion {
    private(set) var progress: CGFloat = 0
    private(set) var recoil: CGFloat = 0
    private(set) var pose = IslandPose.composer

    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var spring: Spring?
    @ObservationIgnored private var dragOrigin: CGFloat?

    var isTracking: Bool { dragOrigin != nil }

    private struct Spring {
        let start: CGFloat
        let target: CGFloat
        let velocity: CGFloat
        let time: CFTimeInterval
        let response: CGFloat
        let startPose: IslandPose
        let targetPose: IslandPose
        let poseDuration: CFTimeInterval?
        let startRecoil: CGFloat
        let bouncesOnOpen: Bool

        func position(at elapsed: CFTimeInterval) -> CGFloat {
            let t = CGFloat(max(0, elapsed))
            let displacement = start - target
            return target + (displacement + (velocity + response * displacement) * t) * exp(-response * t)
        }
    }

    func track(_ translation: CGFloat, distance: CGFloat, floor: CGFloat) {
        if dragOrigin == nil {
            stop()
            dragOrigin = progress
        }
        let origin = dragOrigin ?? progress
        let position = origin + translation / distance
        if position < origin, floor > 0 {
            // Use resistance near the floor to leave room for the next transition
            // when a swipe commits to a submit or keyboard dismissal.
            let range = max(0.04, origin - floor)
            progress = max(0, origin - range * (1 - exp((position - origin) / range)))
        } else {
            progress = min(1, max(0, position))
        }
    }

    func settle(
        to target: CGFloat, pose targetPose: IslandPose, velocity: CGFloat,
        reduceMotion: Bool, poseDuration: CFTimeInterval? = nil, bouncesOnOpen: Bool = false
    ) {
        dragOrigin = nil
        stop()
        let bounces = bouncesOnOpen && !reduceMotion
        guard abs(progress - target) > 0.0005 || (pose != targetPose && target != 0) || bounces || recoil != 0 else {
            progress = target
            pose = targetPose
            return
        }
        // Carry the release velocity into the settle. Cap it near the endpoint so
        // a quick flick cannot overshoot the geometry or make the glass flash.
        let remaining = target - progress
        let response: CGFloat = reduceMotion ? 32 : 17
        let limit = response * abs(remaining)
        let directedVelocity = max(0, velocity * (remaining < 0 ? -1 : 1))
        let releaseVelocity = reduceMotion ? 0 : min(limit, directedVelocity) * (remaining < 0 ? -1 : 1)
        spring = Spring(
            start: progress, target: target, velocity: releaseVelocity,
            time: CACurrentMediaTime(), response: response,
            startPose: pose, targetPose: targetPose, poseDuration: poseDuration,
            startRecoil: recoil, bouncesOnOpen: bounces
        )

        let link = CADisplayLink(target: Tick(owner: self), selector: #selector(Tick.step(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stop() {
        displayLink?.invalidate()
        displayLink = nil
        spring = nil
    }

    private func advance(at time: CFTimeInterval) {
        guard let spring else { return }
        let elapsed = max(0, time - spring.time)
        let next = spring.position(at: elapsed)
        let phase = CGFloat(elapsed) * spring.response
        let shapeProgress: CGFloat
        if let duration = spring.poseDuration {
            let t = min(1, CGFloat(elapsed / duration))
            // Ease both ends of the result expansion while the content follows the presented height.
            shapeProgress = t * t * t * (10 + t * (-15 + 6 * t))
        } else {
            shapeProgress = 1 - (1 + phase) * exp(-phase)
        }
        // Keep the visible content's geometry until it has collapsed to the Island.
        let closing = spring.target == 0
        let shapeComplete = closing || spring.startPose == spring.targetPose || shapeProgress >= 0.999
        // A shallow rebound can finish even if the pull has already fully opened the glass.
        let reboundTime = min(1, CGFloat(elapsed / 0.34))
        let damping = 1 - reboundTime
        let rebound = spring.bouncesOnOpen
            ? 2.3 * sin(2 * .pi * reboundTime) * sin(.pi * reboundTime) * damping
            : 0
        let reboundComplete = (!spring.bouncesOnOpen && spring.startRecoil == 0) || reboundTime == 1
        if (abs(next - spring.target) < 0.001 && shapeComplete && reboundComplete)
            || elapsed >= (spring.poseDuration ?? 0.55) {
            progress = spring.target
            recoil = 0
            pose = spring.targetPose
            stop()
        } else {
            progress = min(1, max(0, next))
            recoil = (spring.startRecoil + rebound) * damping
            if !closing, spring.startPose != spring.targetPose {
                pose = spring.startPose.blend(to: spring.targetPose, amount: shapeProgress)
            }
        }
    }

    private final class Tick: NSObject {
        weak var owner: IslandMotion?
        init(owner: IslandMotion) { self.owner = owner }
        @MainActor @objc func step(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.advance(at: link.targetTimestamp)
        }
    }
}

/// Uses UIKit's release velocity and explicit cancellation, while leaving the
/// keyboard, taps and horizontal history paging to their native recognizers.
struct IslandPan: UIGestureRecognizerRepresentable {
    let onMove: (CGFloat) -> Void
    let onRelease: (CGFloat, CGFloat) -> Void
    let onCancel: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let translation = pan.translation(in: nil).y
        switch pan.state {
        case .began:
            context.coordinator.initialTranslation = translation
            onMove(0)
        case .changed:
            onMove(translation - context.coordinator.initialTranslation)
        case .ended: onRelease(translation, pan.velocity(in: nil).y)
        case .cancelled, .failed: onCancel()
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var initialTranslation: CGFloat = 0

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            return abs(velocity.y) > abs(velocity.x) * 1.25
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
