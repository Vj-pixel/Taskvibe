// PomodoroView.swift

import SwiftUI
import UserNotifications
import AudioToolbox

// MARK: - Pomodoro Mode

enum PomodoroMode: String {
    case work       = "Focus"
    case shortBreak = "Short Break"
    case longBreak  = "Long Break"
}

// MARK: - PomodoroView

struct PomodoroView: View {
    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    // Settings
    @AppStorage("pomodoroWorkMinutes")        private var workMinutes        = 25
    @AppStorage("pomodoroShortBreakMinutes")  private var shortBreakMinutes  = 5
    @AppStorage("pomodoroLongBreakMinutes")   private var longBreakMinutes   = 15
    @AppStorage("pomodoroSessionsBeforeLong") private var sessionsBeforeLong = 4
    @AppStorage("pomodoroAutoStartBreaks")    private var autoStartBreaks    = false
    @AppStorage("pomodoroAutoStartWork")      private var autoStartWork      = false
    @AppStorage("pomodoroSoundEnabled")       private var soundEnabled       = true
    @AppStorage("pomodoroNotifyEnabled")      private var notifyEnabled      = true

    @State private var mode: PomodoroMode = .work
    @State private var secondsRemaining: Int = 25 * 60
    @State private var isRunning = false
    @State private var completedSessions = 0
    @State private var ticker: Timer? = nil
    @State private var showSettings = false

    private var totalSeconds: Int {
        switch mode {
        case .work:       return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak:  return longBreakMinutes * 60
        }
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - secondsRemaining) / Double(totalSeconds)
    }

    private var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var accentColor: Color { AppThemes.find(selectedTheme).accentColor }

    private var modeColor: Color {
        switch mode {
        case .work:       return accentColor
        case .shortBreak: return .green
        case .longBreak:  return .blue
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                gradientManager.gradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    sessionDotsView
                        .padding(.top, 20)

                    Spacer()

                    Text(mode.rawValue.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .kerning(2)
                        .padding(.bottom, 20)

                    timerRingView

                    Spacer()

                    controlsView
                        .padding(.bottom, 20)

                    Button(action: skipToNext) {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Pomodoro")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: syncAfterSettingsChange) {
                PomodoroSettingsSheet(
                    workMinutes: $workMinutes,
                    shortBreakMinutes: $shortBreakMinutes,
                    longBreakMinutes: $longBreakMinutes,
                    sessionsBeforeLong: $sessionsBeforeLong,
                    autoStartBreaks: $autoStartBreaks,
                    autoStartWork: $autoStartWork,
                    soundEnabled: $soundEnabled,
                    notifyEnabled: $notifyEnabled
                )
                .environmentObject(gradientManager)
            }
            .onDisappear { stopTicker() }
        }
    }

    // MARK: - Session Dots

    private var sessionDotsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<sessionsBeforeLong, id: \.self) { i in
                Circle()
                    .fill(i < (completedSessions % sessionsBeforeLong)
                          ? modeColor
                          : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: completedSessions)
            }
        }
    }

    // MARK: - Timer Ring

    private var timerRingView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 14)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(modeColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 240, height: 240)
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 6) {
                Text(timeString)
                    .font(.system(size: 56, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(completedSessions) \(completedSessions == 1 ? "session" : "sessions") today")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Controls

    private var controlsView: some View {
        HStack(spacing: 48) {
            Button(action: resetTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            Button(action: toggleTimer) {
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.22))
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(modeColor, lineWidth: 2)
                        .frame(width: 76, height: 76)
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: isRunning ? 0 : 2)
                }
            }

            Button(action: skipToNext) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Timer Logic

    private func toggleTimer() {
        isRunning ? stopTicker() : startTicker()
    }

    private func startTicker() {
        isRunning = true
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timerFinished()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        isRunning = false
    }

    private func resetTimer() {
        stopTicker()
        secondsRemaining = totalSeconds
    }

    private func timerFinished() {
        stopTicker()

        let wasWork = mode == .work
        if wasWork {
            completedSessions += 1
            mode = completedSessions % sessionsBeforeLong == 0 ? .longBreak : .shortBreak
        } else {
            mode = .work
        }
        secondsRemaining = totalSeconds

        if soundEnabled { AudioServicesPlaySystemSound(1007) }
        if notifyEnabled { sendNotification(nextIsWork: !wasWork) }

        let shouldAutoStart = mode == .work ? autoStartWork : autoStartBreaks
        if shouldAutoStart { startTicker() }
    }

    private func skipToNext() {
        stopTicker()
        if mode == .work {
            completedSessions += 1
            mode = completedSessions % sessionsBeforeLong == 0 ? .longBreak : .shortBreak
        } else {
            mode = .work
        }
        secondsRemaining = totalSeconds
    }

    private func syncAfterSettingsChange() {
        if !isRunning {
            secondsRemaining = totalSeconds
        }
    }

    private func sendNotification(nextIsWork: Bool) {
        let content = UNMutableNotificationContent()
        if nextIsWork {
            content.title = "Break's over!"
            content.body  = "Time to focus. Your next session is ready."
        } else {
            content.title = "Session complete!"
            content.body  = "Nice work! Time for a break."
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - PomodoroSettingsSheet

struct PomodoroSettingsSheet: View {
    @Binding var workMinutes: Int
    @Binding var shortBreakMinutes: Int
    @Binding var longBreakMinutes: Int
    @Binding var sessionsBeforeLong: Int
    @Binding var autoStartBreaks: Bool
    @Binding var autoStartWork: Bool
    @Binding var soundEnabled: Bool
    @Binding var notifyEnabled: Bool

    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: sectionHeader("Durations")) {
                    Stepper("Focus: \(workMinutes) min", value: $workMinutes, in: 1...90)
                        .foregroundColor(.white)
                    Stepper("Short Break: \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
                        .foregroundColor(.white)
                    Stepper("Long Break: \(longBreakMinutes) min", value: $longBreakMinutes, in: 1...60)
                        .foregroundColor(.white)
                    Stepper("Sessions before long break: \(sessionsBeforeLong)", value: $sessionsBeforeLong, in: 1...10)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section(header: sectionHeader("Auto-Start")) {
                    Toggle("Auto-start breaks", isOn: $autoStartBreaks)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                    Toggle("Auto-start next session", isOn: $autoStartWork)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section(header: sectionHeader("Alerts")) {
                    Toggle("Sound on finish", isOn: $soundEnabled)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                    Toggle("Notification on finish", isOn: $notifyEnabled)
                        .tint(AppThemes.find(selectedTheme).accentColor)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.white.opacity(0.10))
            }
            .scrollContentBackground(.hidden)
            .background { gradientManager.gradient.ignoresSafeArea() }
            .navigationTitle("Timer Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundColor(.white.opacity(0.55))
            .font(.caption.weight(.semibold))
    }
}
