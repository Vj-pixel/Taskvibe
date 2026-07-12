import SwiftUI
import SwiftData

struct CalendarTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @State private var date: Date = Date()
    @State private var daypilots: [Daypilot] = []
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedTask: Daypilot? = nil
    @State private var showTaskDetail: Bool = false

    private var calendar: Calendar { Calendar.current }
    
    private var tasksByDay: [Date: [Daypilot]] {
        Dictionary(grouping: daypilots.filter { $0.dueDate != nil }) { task in
            calendar.startOfDay(for: task.dueDate!)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ZStack {
                    Rectangle().fill(gradientManager.gradient)
                    ThemeParticleView()
                }
                .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    monthHeader
                    calendarCard(for: displayedMonth)
                    Divider()
                    taskListForSelectedDate
                    Spacer()
                }
                .padding(.top, 8)
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedTask) { task in
                TaskDetailGlassView(task: task)
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear(perform: fetchTasks)
    }
    
    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth, format: .dateTime.year().month())
                .font(.headline)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.bottom, 8)
    }
    
    private func calendarCard(for month: Date) -> some View {
        VStack(spacing: 4) {
            calendarGrid(for: month)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func calendarGrid(for month: Date) -> some View {
        let weekDays = calendar.shortWeekdaySymbols
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let weekdayOffset = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7
        let days = daysInMonth(for: month)
        let leadingEmpty = weekdayOffset
        let totalCells = days.count + leadingEmpty
        let rows = Int(ceil(Double(totalCells) / 7.0))
        
        return VStack(spacing: 4) {
            HStack {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cell = row * 7 + col
                        if cell < leadingEmpty || cell - leadingEmpty >= days.count {
                            Spacer().frame(maxWidth: .infinity, minHeight: 40)
                        } else {
                            let day = days[cell - leadingEmpty]
                            let isToday = calendar.isDateInToday(day)
                            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                            let hasTasks = tasksByDay[day]?.isEmpty == false
                            Button(action: { selectedDate = day }) {
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.2))
                                            .frame(width: 36, height: 36)
                                    }
                                    Text("\(calendar.component(.day, from: day))")
                                        .fontWeight(isToday ? .bold : .regular)
                                        .foregroundColor(isToday ? .blue : .primary)
                                    if hasTasks {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                            .offset(y: 14)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 40)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func daysInMonth(for month: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        var days: [Date] = []
        var day = monthInterval.start
        while day < monthInterval.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }
    
    private var taskListForSelectedDate: some View {
        let dayTasks = tasksByDay[calendar.startOfDay(for: selectedDate)] ?? []
        return Group {
            if dayTasks.isEmpty {
                Text("No tasks for this day")
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(dayTasks) { task in
                        Button {
                            selectedTask = task
                        } label: {
                            TaskListGlassRow(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: newDate)
            // If selectedDate is not in the new month, update it to the first of the new month
            if !calendar.isDate(selectedDate, equalTo: displayedMonth, toGranularity: .month) {
                selectedDate = displayedMonth
            }
        }
    }
    
    private func fetchTasks() {
        let descriptor = FetchDescriptor<Daypilot>(sortBy: [SortDescriptor(\.dueDate, order: .forward)])
        do {
            daypilots = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch tasks: \(error)")
        }
    }
}

// Glass-style row for a task in the list
struct TaskListGlassRow: View {
    let task: Daypilot
    var body: some View {
        HStack {
            Circle()
                .fill(colorForUrgency(task.urgency))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundColor(.primary)
                if let due = task.dueDate {
                    Text(due, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// Glass-style detail view for a task
struct TaskDetailGlassView: View {
    let task: Daypilot
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
            
            VStack(spacing: 16) {
                Text(task.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                if let due = task.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Due: \(due.formatted(date: .abbreviated, time: .shortened))")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text("Urgency: \(task.urgency.rawValue)")
                }
                .font(.subheadline)
                .foregroundColor(colorForUrgency(task.urgency))
                
                if task.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Completed")
                            .foregroundColor(.green)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .background(
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

// Helper for urgency color — reads the active theme from UserDefaults
private func colorForUrgency(_ level: UrgencyLevel) -> Color {
    let themeId = UserDefaults.standard.string(forKey: "selectedTheme") ?? "original"
    return AppThemes.find(themeId).urgencyColor(for: level)
}
// Calendar extension for startOfMonth
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
