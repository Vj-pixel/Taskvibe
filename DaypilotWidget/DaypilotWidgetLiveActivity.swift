// DaypilotWidgetLiveActivity.swift
// Pomodoro Live Activity — Dynamic Island + Lock Screen

import ActivityKit
import WidgetKit
import SwiftUI

// PomodoroActivityAttributes is defined in PomodoroActivityAttributes.swift
// That file must be added to this widget target via File Inspector → Target Membership.

struct DaypilotWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            LockScreenActivityView(context: context)
                .activityBackgroundTint(Color(white: 0.08))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ProgressRingView(progress: progress(context.state), size: 46)
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timeString(context.state.secondsLeft))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(context.state.sessionLabel.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .tracking(1.5)
                    }
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    if !context.attributes.taskTitle.isEmpty {
                        Text(context.attributes.taskTitle)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: context.state.isRunning ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(context.state.isRunning ? "Running" : "Paused")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                ProgressRingView(progress: progress(context.state), size: 20)
                    .padding(.leading, 4)
            } compactTrailing: {
                Text(timeString(context.state.secondsLeft))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.trailing, 4)
            } minimal: {
                ProgressRingView(progress: progress(context.state), size: 20)
            }
        }
    }

    private func progress(_ state: PomodoroActivityAttributes.ContentState) -> Double {
        guard state.totalSeconds > 0 else { return 0 }
        return Double(state.secondsLeft) / Double(state.totalSeconds)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Lock Screen View

private struct LockScreenActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        HStack(spacing: 18) {
            ProgressRingView(progress: progress, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(timeString(context.state.secondsLeft))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(context.state.sessionLabel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1.5)
                if !context.attributes.taskTitle.isEmpty {
                    Text(context.attributes.taskTitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: context.state.isRunning ? "timer" : "pause.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(16)
    }

    private var progress: Double {
        guard context.state.totalSeconds > 0 else { return 0 }
        return Double(context.state.secondsLeft) / Double(context.state.totalSeconds)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Progress Ring

struct ProgressRingView: View {
    let progress: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: size * 0.13)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: size, height: size)
    }
}
