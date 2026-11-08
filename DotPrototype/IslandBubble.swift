import SwiftUI

struct IslandBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let stage: DotStage
    let inputFocused: Bool
    let openness: CGFloat
    let recoil: CGFloat
    let pose: IslandPose
    let fullWidth: CGFloat
    let answerFont: CGFloat
    @Binding var prompt: String
    let recentChat: RecentDotChat?
    let voiceWordCount: Int
    let startVoice: () -> Void
    let openPersonalDot: () -> Void
    let sendTyped: () -> Void
    let sendVoice: () -> Void
    let openRecent: (RecentDotChat) -> Void
    let dismiss: () -> Void

    private var travel: CGFloat { min(1, max(0, openness)) }
    private var visible: Double { Double(ramp(from: 0, to: 0.08)) }
    private var contentOpacity: Double { Double(ramp(from: 0.28, to: 0.76)) }
    private var historyProgress: CGFloat { ramp(from: 0.88, to: 1) * pose.history }
    private var composerOpacity: Double { Double(ramp(width / fullWidth, from: 0.83, to: 0.98)) }
    private var answerOpacity: Double { Double(ramp(from: 0.79, to: 0.98)) }

    private var lensWeight: CGFloat { reduceMotion ? 0 : pose.history }
    private var lens: CGFloat { lensWeight * sin(.pi * ramp(from: 0.06, to: 0.97)) }
    private var width: CGFloat {
        let spread = travel * (1.22 - 0.22 * travel)
        let lensSpread = pow(travel, 1.68)
        let presentedSpread = spread + (lensSpread - spread) * lensWeight
        return 126 + (fullWidth - 126) * pose.width * presentedSpread
    }
    private var height: CGFloat { 37 + (pose.height - 37) * travel + 23 * lens }

    private var outline: RoundedRectangle {
        RoundedRectangle(cornerRadius: min(height / 2, 19 + 29 * travel + 14 * lens))
    }

    var body: some View {
        ZStack(alignment: .top) {
            RecentDotChats(width: fullWidth, open: openRecent)
                .opacity(Double(historyProgress))
                .scaleEffect(reduceMotion ? 1 : 0.84 + 0.16 * historyProgress, anchor: .top)
                .offset(y: height + 12 - (reduceMotion ? 0 : 24 * (1 - historyProgress)))
                .allowsHitTesting(inputFocused)
                .accessibilityHidden(!inputFocused)

            ZStack(alignment: .topLeading) {
                surface
                if stage == .listening {
                    listeningRow
                        .transition(.identity)
                } else {
                    inputRow
                        .frame(width: fullWidth)
                        .offset(x: (width - fullWidth) / 2)
                        .opacity(stage == .home || stage == .input ? composerOpacity : 0)
                        .animation(.easeOut(duration: 0.08), value: stage)
                        .allowsHitTesting(inputFocused)
                        .accessibilityHidden(!inputFocused)
                        .transition(.identity)
                }
                if stage.isLoading || (stage == .answer && recentChat == nil) {
                    reminderResult
                }
                if stage == .answer, let recentChat {
                    recentResult(recentChat)
                        .transition(.opacity)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
            .clipShape(outline)
            .opacity(visible)
        }
        .frame(width: fullWidth, height: height, alignment: .top)
        .offset(y: 3 * lens - 3.5 * recoil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("island-bubble")
    }

    private var resultExpansion: CGFloat {
        guard stage == .answer else { return 0 }
        let start = IslandPose.loading.height
        let end = IslandPose.reminders(fontSize: answerFont).height
        return min(1, max(0, (pose.height - start) / (end - start)))
    }

    private var reminderResult: some View {
        let expansion = resultExpansion
        let summaryReveal = ramp(expansion, from: 0.34, to: 0.71)
        let listReveal = ramp(expansion, from: 0.53, to: 0.95)
        let loaderEntrance = stage == .searching ? 1 - ramp(pose.width, from: 0.80, to: 0.86) : 1
        return ZStack(alignment: .topLeading) {
            loadingRow(spinning: expansion < 0.45 && loaderEntrance > 0)
                .offset(y: reduceMotion ? 0 : -8 * expansion)
                .opacity(Double(loaderEntrance * (1 - ramp(expansion, from: 0.10, to: 0.45))))
                .accessibilityHidden(stage == .answer)

            VStack(alignment: .leading, spacing: 16) {
                Text("Adi, here are your reminders.")
                    .font(.system(size: answerFont + 2, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(Double(summaryReveal))

                VStack(alignment: .leading, spacing: 15) {
                    reminder("Today", "Send the portfolio draft")
                    reminder("Tomorrow", "Pick up the parcel")
                    reminder("In 2 days", "Review next week’s plans")
                }
                .offset(y: reduceMotion ? 0 : 8 * (1 - listReveal))
                .opacity(Double(listReveal))
            }
            .padding(.horizontal, 26)
            .padding(.top, 38)
            .frame(width: fullWidth, alignment: .leading)
            .offset(x: (width - fullWidth) / 2, y: reduceMotion ? 0 : 6 * (1 - summaryReveal))
            .foregroundStyle(.white)
            .opacity(answerOpacity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("island-message")
            .accessibilityHidden(stage != .answer || expansion < 0.98)
            .accessibilityAction(named: "Dismiss", dismiss)
        }
        .opacity(contentOpacity)
    }

    private func loadingRow(spinning: Bool) -> some View {
        HStack(spacing: 12) {
            ThinkingOrbit(paused: !spinning)
            Text("Searching reminders")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: min(width, 126 + (fullWidth - 126) * IslandPose.loading.width), alignment: .leading)
        .frame(height: IslandPose.loading.height, alignment: .center)
        .offset(y: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching reminders")
        .accessibilityIdentifier("island-state")
    }

    private func reminder(_ day: String, _ title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: "circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .accessibilityHidden(true)
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            Text(day)
                .foregroundStyle(.white.opacity(0.63))
                .fixedSize()
        }
        .font(.system(size: answerFont - 1))
    }

    private func recentResult(_ chat: RecentDotChat) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(chat.title)
                .font(.system(size: answerFont, weight: .semibold))
            Text(chat.folder)
                .font(.system(size: answerFont - 3))
                .foregroundStyle(.white.opacity(0.75))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 26)
        .padding(.top, 38)
        .frame(width: fullWidth, alignment: .leading)
        .offset(x: (width - fullWidth) / 2)
        .opacity(answerOpacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("island-message")
        .accessibilityAction(named: "Dismiss", dismiss)
    }

    private func ramp(from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        ramp(travel, from: lower, to: upper)
    }

    private func ramp(_ progress: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        let fraction = min(1, max(0, (progress - lower) / (upper - lower)))
        return fraction * fraction * (3 - 2 * fraction)
    }

    private var surface: some View {
        let shape = outline
        return Color.clear
            .frame(width: width, height: height)
            .glassEffect(.clear, in: shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.98), location: 0),
                            .init(color: .black.opacity(0.69), location: 0.70),
                            .init(color: .black.opacity(0.18), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
            .overlay {
                if lens > 0 {
                    let highlight = RadialGradient(
                        colors: [.white.opacity(0.8), Color(red: 0.55, green: 0.78, blue: 1).opacity(0.30), .clear],
                        center: .center, startRadius: 0, endRadius: width * 0.36
                    )
                    Ellipse()
                        .fill(highlight)
                        .frame(width: width * 0.76, height: 7)
                        .blur(radius: 1.8)
                        .offset(y: height * 0.16)
                        .opacity(Double(lens * 0.85))
                }
            }
            .overlay(alignment: .bottom) {
                let answerGlow = ramp(resultExpansion, from: 0.38, to: 0.96)
                Capsule()
                    .fill(.white)
                    .frame(width: width * (0.22 + 0.16 * answerGlow), height: 2 + 2 * answerGlow)
                    .blur(radius: 3.5 + 2.5 * answerGlow)
                    .padding(.bottom, 1)
                    .opacity(Double(ramp(from: 0.28, to: 1)) * (0.48 + 0.34 * answerGlow))
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear, .white.opacity(0.36)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var inputRow: some View {
        HStack(spacing: 4) {
            Button(action: openPersonalDot) {
                dot
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open your Dot in ChatGPT")
            .accessibilityIdentifier("personal-dot")
            AskInput(text: $prompt, focused: inputFocused, submit: sendTyped)
                .frame(height: 44)
            Button(action: startVoice) {
                Image(systemName: "mic")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start voice")
            .accessibilityIdentifier("top-mic")
        }
        .padding(.leading, 21)
        .padding(.trailing, 27)
        .padding(.top, 28)
    }

    private var listeningRow: some View {
        HStack(spacing: 11) {
            dot
            VStack(alignment: .leading, spacing: 2) {
                Text("Listening")
                    .font(.system(size: 16, weight: .medium))
                    .accessibilityIdentifier("island-state")
                HStack(spacing: 3.5) {
                    ForEach(VoiceDemo.script.indices, id: \.self) { index in
                        Text(VoiceDemo.script[index].word)
                            .opacity(index < voiceWordCount ? 1 : 0)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(VoiceDemo.script.prefix(voiceWordCount).map(\.word).joined(separator: " "))
                .accessibilityIdentifier("voice-transcript")
                .accessibilityHidden(voiceWordCount == 0)
            }
            Spacer(minLength: 0)
            Button(action: sendVoice) {
                waveform
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send voice")
        }
        .padding(.leading, 21)
        .padding(.trailing, 13)
        .padding(.top, 25)
        .opacity(contentOpacity)
    }

    private var dot: some View {
        Image("PersonalDot")
            .resizable()
            .scaledToFill()
            .scaleEffect(1.12)
            .frame(width: 32, height: 32)
            .clipShape(.rect(cornerRadius: 10))
    }

    private var waveform: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.7) {
                ForEach(0..<5) { index in
                    let wave = abs(sin(time * 7 + Double(index) * 1.3))
                    let amplitude = reduceMotion ? 0.30 : 0.68
                    Capsule()
                        .fill(.white.opacity(0.86))
                        .frame(width: 2.3, height: 3 + 18 * amplitude * wave)
                }
            }
        }
        .accessibilityHidden(true)
    }
}


private struct ThinkingOrbit: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || paused)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let rotation = reduceMotion ? 0 : time.truncatingRemainder(dividingBy: 1.3) * 2 * .pi / 1.3
            ZStack {
                ForEach(0..<6) { index in
                    let phase = Double(index) / 6
                    let angle = phase * 2 * .pi + rotation
                    let strength = 1 - phase
                    let size = 3 + 3.3 * strength
                    Circle()
                        .fill(.white.opacity(0.20 + 0.80 * strength))
                        .frame(width: size, height: size)
                        .shadow(color: .white.opacity(0.45 * strength), radius: 2.5)
                        .offset(x: cos(angle) * 11, y: sin(angle) * 11)
                }
            }
            .frame(width: 34, height: 34)
        }
        .accessibilityHidden(true)
    }
}
