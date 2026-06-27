// PomodoroView.swift

import SwiftUI
import AudioToolbox

struct PomodoroView: View {
    var linkedTask: Daypilot? = nil

    @State private var totalSeconds: Int = 25 * 60
    @State private var secondsLeft: Int = 25 * 60
    @State private var isRunning = false
    @State private var sessionLabel = "Focus"
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    private let presets: [(label: String, minutes: Int)] = [
        ("Focus", 25), ("Short Break", 5), ("Long Break", 15)
    ]

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.color1, theme.color2, theme.color3],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // Header
                VStack(spacing: 4) {
                    Text("Focus Timer")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    if let task = linkedTask {
                        Text(task.title)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                // Preset chips
                HStack(spacing: 10) {
                    ForEach(presets, id: \.label) { preset in
                        Button {
                            guard !isRunning else { return }
                            sessionLabel = preset.label
                            totalSeconds = preset.minutes * 60
                            secondsLeft = preset.minutes * 60
                        } label: {
                            Text(preset.label)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(sessionLabel == preset.label ? .black : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(sessionLabel == preset.label ? Color.white : Color.white.opacity(0.18))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunning)
                    }
                }

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 12)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: 2) {
                        Text(timeString)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(sessionLabel.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                    }
                }

                // Controls
                HStack(spacing: 32) {
                    Button {
                        secondsLeft = totalSeconds
                        isRunning = false
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        isRunning.toggle()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(theme.color1)
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        // Skip to next session
                        let idx = presets.firstIndex(where: { $0.label == sessionLabel }) ?? 0
                        let next = presets[(idx + 1) % presets.count]
                        sessionLabel = next.label
                        totalSeconds = next.minutes * 60
                        secondsLeft = next.minutes * 60
                        isRunning = false
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 32)
        }
        .onReceive(timer) { _ in
            guard isRunning, secondsLeft > 0 else {
                if isRunning && secondsLeft == 0 { handleTimerEnd() }
                return
            }
            secondsLeft -= 1
        }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(secondsLeft) / Double(totalSeconds)
    }

    private var timeString: String {
        let m = secondsLeft / 60
        let s = secondsLeft % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func handleTimerEnd() {
        isRunning = false
        AudioServicesPlaySystemSound(1005) // chime
        // Auto-advance to next preset
        let idx = presets.firstIndex(where: { $0.label == sessionLabel }) ?? 0
        let next = presets[(idx + 1) % presets.count]
        sessionLabel = next.label
        totalSeconds = next.minutes * 60
        secondsLeft = next.minutes * 60
    }
}
