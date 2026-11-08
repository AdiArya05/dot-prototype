import SwiftUI
import UIKit

@main
struct DotPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            DotExperience()
                .preferredColorScheme(.dark)
        }
    }
}

enum DotStage {
    case home, input, listening, searching, answer

    var isOpen: Bool { self != .home }
    var isLoading: Bool { self == .searching }
}

enum VoiceDemo {
    static let script: [(word: String, delay: Duration)] = [
        ("Reminders", .milliseconds(520)),
        ("for", .milliseconds(470)),
        ("the", .milliseconds(290)),
        ("next", .milliseconds(350)),
        ("three", .milliseconds(430)),
        ("days", .milliseconds(390))
    ]
}

private struct DotExperience: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var answerFont = 18.0
    @State private var stage: DotStage = .home
    @State private var closingStage: DotStage?
    @State private var motion = IslandMotion()
    @State private var prompt = ""
    @State private var recentChat: RecentDotChat?
    @State private var voiceWordCount = 0
    @State private var showDotUnavailable = false

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 28, 392)
            let progress = motion.progress
            let homeDepth = reduceMotion ? 0 : progress * progress * (3 - 2 * progress)
            let rebound = reduceMotion ? 0 : motion.recoil
            ZStack(alignment: .top) {
                HomeScreen(size: geometry.size, openAsk: { present(.input) })
                    .equatable()
                    .scaleEffect(1 - 0.022 * homeDepth - 0.012 * rebound)
                    .offset(y: 4 * homeDepth + 3 * rebound)
                    .allowsHitTesting(!stage.isOpen)
                    .accessibilityHidden(stage.isOpen)
                Color.black.opacity(Double(motion.progress) * 0.06)
                    .allowsHitTesting(false)
                IslandBubble(
                    stage: stage == .home ? closingStage ?? .home : stage,
                    inputFocused: stage == .input,
                    openness: progress,
                    recoil: rebound,
                    pose: motion.pose,
                    fullWidth: width,
                    answerFont: answerFont,
                    prompt: $prompt,
                    recentChat: recentChat,
                    voiceWordCount: voiceWordCount,
                    startVoice: { present(.listening) },
                    openPersonalDot: openPersonalDot,
                    sendTyped: { sendTyped() },
                    sendVoice: { submit() },
                    openRecent: openRecent,
                    dismiss: { present(.home) }
                )
                .padding(.top, 14)
                .allowsHitTesting(stage.isOpen)
                .accessibilityHidden(!stage.isOpen)
            }
            .contentShape(Rectangle())
            .gesture(IslandPan(onMove: trackPull, onRelease: releasePull, onCancel: { settle() }))
        }
        // Keep the scene fixed when the status bar and the system keyboard change.
        .ignoresSafeArea()
        .background { Wallpaper().ignoresSafeArea() }
        .statusBarHidden(motion.progress * motion.pose.width > 0.58)
        .alert("Open your Dot in ChatGPT", isPresented: $showDotUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Use the latest ChatGPT app and sign in to the account where you set up your Dot.")
        }
        .onChange(of: motion.progress) { _, progress in
            if progress == 0, stage == .home, !motion.isTracking { closingStage = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, stage == .listening || stage.isLoading { present(.home) }
        }
        .task(id: stage) {
            switch stage {
            case .listening:
                for (index, entry) in VoiceDemo.script.enumerated() {
                    do { try await Task.sleep(for: entry.delay) } catch { return }
                    guard stage == .listening, !Task.isCancelled else { return }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                        voiceWordCount = index + 1
                    }
                }
            case .searching:
                do {
                    try await Task.sleep(for: .milliseconds(2150))
                    while motion.isTracking { try await Task.sleep(for: .milliseconds(25)) }
                    try Task.checkCancellation()
                    present(.answer)
                } catch { return }
            case .home, .input, .answer:
                break
            }
        }
    }

    private var dragDistance: CGFloat { stage.isOpen ? 170 : 174 }

    private var submitsOnSwipe: Bool {
        stage == .listening || (stage == .input && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func trackPull(_ translation: CGFloat) {
        // Keep the glass visible until a committed close starts dismissing the keyboard.
        let floor: CGFloat = submitsOnSwipe ? 0.54 : (stage == .input ? 0.24 : 0)
        motion.track(translation, distance: dragDistance, floor: floor)
    }

    private func releasePull(_ translation: CGFloat, _ velocity: CGFloat) {
        let release = velocity / dragDistance
        let projected = translation + min(84, max(-84, velocity * 0.10))
        if translation > 24, projected > 71, stage == .home || stage == .answer || stage.isLoading {
            if stage == .home { UISelectionFeedbackGenerator().selectionChanged() }
            present(.input, velocity: release)
        } else if translation < -22, projected < -68 {
            switch stage {
            case .input: sendTyped(velocity: release)
            case .listening: submit(velocity: release)
            case .home: settle(velocity: release)
            case .searching, .answer: present(.home, velocity: release)
            }
        } else {
            settle(velocity: release)
        }
    }

    private var pose: IslandPose {
        switch stage {
        case .home, .input: .composer
        case .listening: .init(width: 1, height: 88)
        case .searching: .loading
        case .answer: recentChat == nil ? .reminders(fontSize: answerFont) : .init(width: 1, height: 120)
        }
    }

    private func settle(velocity: CGFloat = 0, bouncesOnOpen: Bool = false) {
        let revealDuration: TimeInterval? = stage == .answer && recentChat == nil && !reduceMotion ? 0.66 : nil
        motion.settle(
            to: stage.isOpen ? 1 : 0, pose: pose, velocity: velocity,
            reduceMotion: reduceMotion, poseDuration: revealDuration, bouncesOnOpen: bouncesOnOpen
        )
    }

    private func present(_ next: DotStage, velocity: CGFloat = 0) {
        let opensFromHome = stage == .home && next == .input
        if stage != next {
            closingStage = next == .home && motion.progress > 0 ? stage : nil
            if next == .input { prompt = "" }
            if next == .listening {
                voiceWordCount = 0
                stage = next
            } else {
                withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.23)) { stage = next }
            }
        }
        settle(velocity: velocity, bouncesOnOpen: opensFromHome)
    }

    private func openPersonalDot() {
        UIApplication.shared.open(ChatGPTHandoff.dot, options: [.universalLinksOnly: true]) { accepted in
            if accepted { present(.home) }
            else { showDotUnavailable = true }
        }
    }

    private func openRecent(_ chat: RecentDotChat) {
        recentChat = chat
        present(.answer)
    }

    private func sendTyped(velocity: CGFloat = 0) {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            present(.home, velocity: velocity)
            return
        }
        submit(velocity: velocity)
    }

    private func submit(velocity: CGFloat = 0) {
        recentChat = nil
        present(.searching, velocity: velocity)
    }
}
