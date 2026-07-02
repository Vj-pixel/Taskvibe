// DaypilotWidget.swift

import WidgetKit
import SwiftUI

// MARK: - Shared Data Models

struct WidgetTask: Codable {
    let title: String
    let urgency: String
    let emoji: String
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let bestStreak: Int
    let habitsDoneToday: Int
}

// MARK: - Timeline Provider

struct DaypilotWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: .now,
            tasks: [
                WidgetTask(title: "Morning run", urgency: "Urgent", emoji: "🏃"),
                WidgetTask(title: "Read 30 mins", urgency: "Kinda Urgent", emoji: "📚"),
            ],
            bestStreak: 7,
            habitsDoneToday: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = readEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readEntry() -> WidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.daypilot.shared")
        var tasks: [WidgetTask] = []
        if let data = defaults?.data(forKey: "widgetTasks"),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            tasks = raw.map { WidgetTask(title: $0["title"] ?? "", urgency: $0["urgency"] ?? "", emoji: $0["emoji"] ?? "") }
        }
        return WidgetEntry(
            date: .now,
            tasks: tasks,
            bestStreak: defaults?.integer(forKey: "widgetBestStreak") ?? 0,
            habitsDoneToday: defaults?.integer(forKey: "widgetHabitsDoneToday") ?? 0
        )
    }
}

// MARK: - Urgency Dot Color

private func urgencyColor(_ urgency: String) -> Color {
    switch urgency {
    case "Urgent":       return .red
    case "Kinda Urgent": return .orange
    default:             return Color(white: 0.55)
    }
}

// MARK: - Small Widget View

struct DaypilotSmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.06), Color.blue.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "metronome.fill")
                        .font(.caption2)
                    Text("Daypilot")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(.white.opacity(0.55))

                Spacer()

                if entry.bestStreak > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 28))
                        Text("\(entry.bestStreak)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Text("day streak")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.65))
                } else {
                    Text("No streak\nyet — start today!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                HStack {
                    Image(systemName: "checklist")
                        .font(.caption2)
                    Text("\(entry.tasks.count) tasks left")
                        .font(.caption2.weight(.medium))
                }
                .foregroundColor(.white.opacity(0.55))
            }
            .padding(14)
        }
    }
}

// MARK: - Medium Widget View

struct DaypilotMediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.06), Color.blue.opacity(0.48)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            HStack(spacing: 0) {
                // Left — streak stat
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "metronome.fill")
                            .font(.caption2)
                        Text("Today")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    if entry.bestStreak > 0 {
                        Text("🔥")
                            .font(.system(size: 26))
                        Text("\(entry.bestStreak)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("day streak")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Text("Start your\nstreak today!")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                        Text("\(entry.habitsDoneToday) habits done")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.5))
                }
                .padding(14)
                .frame(width: 110)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Right — task list
                VStack(alignment: .leading, spacing: 6) {
                    if entry.tasks.isEmpty {
                        Spacer()
                        Text("All clear! 🎉")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("No tasks left today.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                        Spacer()
                    } else {
                        ForEach(Array(entry.tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                            HStack(spacing: 8) {
                                if task.emoji.isEmpty {
                                    Circle()
                                        .fill(urgencyColor(task.urgency))
                                        .frame(width: 7, height: 7)
                                } else {
                                    Text(task.emoji)
                                        .font(.system(size: 13))
                                }
                                Text(task.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        if entry.tasks.count > 3 {
                            Text("+\(entry.tasks.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.45))
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.trailing, 14)
                .padding(.leading, 10)
            }
        }
    }
}

// MARK: - Widget Configurations

struct DaypilotSmallWidget: Widget {
    let kind = "DaypilotSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaypilotWidgetProvider()) { entry in
            DaypilotSmallWidgetView(entry: entry)
                .containerBackground(Color(white: 0.06), for: .widget)
        }
        .configurationDisplayName("Daypilot")
        .description("Your best streak and tasks at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct DaypilotMediumWidget: Widget {
    let kind = "DaypilotMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DaypilotWidgetProvider()) { entry in
            DaypilotMediumWidgetView(entry: entry)
                .containerBackground(Color(white: 0.06), for: .widget)
        }
        .configurationDisplayName("Daypilot Today")
        .description("Streak stats and your top tasks for today.")
        .supportedFamilies([.systemMedium])
    }
}
