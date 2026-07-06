import SwiftUI
import SwiftData

struct TaskHistoryView: View {
    @Query(filter: #Predicate<Daypilot> { $0.isCompleted == true })
    private var completedTasks: [Daypilot]

    @AppStorage("selectedTheme") private var selectedTheme = "original"
    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    @Environment(\.dismiss) private var dismiss

    private var groupedByWeek: [(String, [Daypilot])] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        // Key: (weekStart: Date, label: String)
        var weekMap: [(start: Date, label: String, tasks: [Daypilot])] = []

        for task in completedTasks where task.parent == nil {
            let ref = task.dueDate ?? task.createdAt
            guard let interval = cal.dateInterval(of: .weekOfYear, for: ref) else { continue }
            let start = interval.start
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            let label = "Week of \(formatter.string(from: start)) – \(formatter.string(from: end))"
            if let idx = weekMap.firstIndex(where: { $0.start == start }) {
                weekMap[idx].tasks.append(task)
            } else {
                weekMap.append((start: start, label: label, tasks: [task]))
            }
        }

        return weekMap
            .sorted { $0.start > $1.start }
            .map { ($0.label, $0.tasks) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(white: 0.04), theme.color1.opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                if completedTasks.filter({ $0.parent == nil }).isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 52)).foregroundColor(.white.opacity(0.2))
                        Text("No completed tasks yet")
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    List {
                        ForEach(groupedByWeek, id: \.0) { week, tasks in
                            Section {
                                ForEach(tasks.sorted { ($0.dueDate ?? $0.createdAt) > ($1.dueDate ?? $1.createdAt) }) { task in
                                    HistoryTaskRow(task: task, theme: theme)
                                        .listRowBackground(Color.white.opacity(0.07))
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                            } header: {
                                HStack {
                                    Text(week)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Task History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

}

private struct HistoryTaskRow: View {
    let task: Daypilot
    let theme: ThemeOption

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let emoji = task.taskEmoji {
                        Text(emoji).font(.system(size: 14))
                    }
                    Text(task.title)
                        .font(.callout.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let tag = task.userTag {
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(theme.accentColor.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundColor(theme.accentColor)
                    }
                    if let date = task.dueDate {
                        Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption2).foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            Spacer()

            if task.type == .habit && task.streakCount > 0 {
                Label("\(task.streakCount)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
