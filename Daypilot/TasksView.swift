// TasksView.swift

import SwiftUI
import UIKit
import SwiftData
import UserNotifications
import UniformTypeIdentifiers

// MARK: - StatusRing (progress arc only — icon moved to corner badge)

struct StatusRing: View {
    let progress: Int
    let color: Color
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(progress) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .frame(width: 38, height: 38)
        .contentShape(Circle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Status Corner Badge (tiny icon, top-right of card, tasks only)

struct StatusCornerBadge: View {
    let status: TaskStatus
    let color: Color

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(4)
            .background(Circle().fill(.ultraThinMaterial))
    }

    private var iconName: String {
        switch status {
        case .open:       return "circle"
        case .inProgress: return "clock.fill"
        case .blocked:    return "xmark.circle.fill"
        case .completed:  return "checkmark.circle.fill"
        }
    }
}

// MARK: - Progress Overlay Views

struct SegmentedOutlineProgress: View {
    let progress: Int
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, r = cornerRadius
            let perimeter = 2 * (w - 2*r) + 2 * (h - 2*r) + 2 * .pi * r
            let slotLen  = perimeter / 16
            let dashLen  = slotLen * 0.72
            let gapLen   = slotLen * 0.28
            ZStack {
                RoundedRectangle(cornerRadius: r)
                    .stroke(Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                              dash: [dashLen, gapLen]))
                RoundedRectangle(cornerRadius: r)
                    .trim(from: 0, to: CGFloat(max(0, min(100, progress))) / 100)
                    .stroke(color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round,
                                              dash: [dashLen, gapLen]))
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }
        }
    }
}

struct TopBarProgress: View {
    let progress: Int
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 4)
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(100, progress))) / 100,
                           height: 4)
                    .animation(.easeInOut(duration: 0.35), value: progress)
            }
        }
        .frame(height: 4)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: cornerRadius
            )
        )
    }
}

// MARK: - Future Habit Stripes (diagonal hatch pattern for locked habits)

struct FutureHabitStripes: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 13
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(path, with: .color(.gray.opacity(0.22)), lineWidth: 1.5)
                x += spacing
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Action Hint View (unified, replaces four separate backgrounds)

struct ActionHintView: View {
    let icon: String
    let label: String
    let tint: Color
    let isTriggered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [tint, tint.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                VStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                    Text(label)
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .scaleEffect(isTriggered ? 1.12 : 0.82)
                .opacity(isTriggered ? 1.0 : 0.75)
                .animation(.spring(response: 0.2, dampingFraction: 0.55), value: isTriggered)
            )
    }
}

// MARK: - Task Content View

struct TaskContentView: View {
    let task: Daypilot
    let dragOffset: CGSize
    let isCrumpled: Bool
    let isDragging: Bool
    let showingAction: Bool
    let onStatusChange: (TaskStatus) -> Void
    /// When viewing a habit on a specific calendar date, pass that date so we
    /// show the occurrence date rather than the habit's original start date.
    var occurrenceDate: Date? = nil
    var isFutureHabit: Bool = false

    @AppStorage("selectedTheme")       private var selectedTheme       = "original"
    @AppStorage("progressDisplayStyle") private var progressDisplayStyle = "segmented"

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if task.type == .task {
                StatusRing(progress: task.progress, color: ringColor) {
                    let all = TaskStatus.allCases
                    let idx = all.firstIndex(of: task.status) ?? 0
                    onStatusChange(all[(idx + 1) % all.count])
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.headline)
                    if task.sourceTag == "Canvas" {
                        Text("Canvas")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.88, green: 0.28, blue: 0.08))
                            .clipShape(Capsule())
                    }
                }

                let displayDate = (task.type == .habit ? occurrenceDate : nil) ?? task.dueDate
                if let due = displayDate {
                    Text("Due: \(due.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                if task.type == .habit {
                    let doneToday = HabitScheduler.isDoneToday(task)
                    HStack(spacing: 6) {
                        Text(task.habitFrequency.rawValue)
                            .font(.caption2)
                            .foregroundColor(.blue)
                        if task.streakCount > 0 {
                            Text("🔥 \(task.streakCount) day streak")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    if doneToday {
                        Text("✓ Done for today")
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.85))
                    }
                    if isFutureHabit {
                        Text("Available tomorrow")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Text(task.urgency.rawValue)
                    .font(.caption2)
                    .foregroundColor(.primary.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 350, maxWidth: 350, minHeight: 100, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                if isFutureHabit {
                    FutureHabitStripes()
                }
            }
        )
        .overlay(alignment: .top) {
            if task.type == .task && progressDisplayStyle == "topBar" {
                TopBarProgress(progress: task.progress, color: ringColor, cornerRadius: 12)
                    .padding(.horizontal, 5)
                    .padding(.top, 4)
            }
        }
        .overlay(
            ZStack(alignment: .topTrailing) {
                if task.type == .habit {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ringColor, lineWidth: 3)
                } else if progressDisplayStyle == "segmented" {
                    SegmentedOutlineProgress(progress: task.progress, color: ringColor, cornerRadius: 12)
                        .padding(4)
                }
                if task.type == .task {
                    StatusCornerBadge(status: task.status, color: ringColor)
                        .padding(6)
                }
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .shadow(color: .white.opacity(0.1), radius: 1, x: 0, y: 1)
        .scaleEffect(taskScale)
        .rotationEffect(.degrees(taskRotation))
        .opacity(showingAction ? 0.3 : cardOpacity)
        .offset(dragOffset)
    }

    private var ringColor: Color { AppThemes.find(selectedTheme).urgencyColor(for: task.urgency) }

    private var taskScale: CGFloat {
        isDragging ? 0.97 : 1.0
    }

    private var taskRotation: Double { 0 }

    private var cardOpacity: Double {
        if isFutureHabit { return 0.55 }
        return task.type == .habit && HabitScheduler.isDoneToday(task) ? 0.45 : 1.0
    }
}


// MARK: - Draggable Task View

struct DraggableTaskView: View {
    let task: Daypilot
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onStatusChange: (TaskStatus) -> Void
    var occurrenceDate: Date? = nil
    var isFutureHabit: Bool = false

    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var readyToDelete = false
    @State private var readyToComplete = false
    @State private var readyToEdit = false
    @State private var readyToShare = false
    @State private var showFutureHabitAlert = false

    private let deleteThreshold: CGFloat  = -110
    private let completeThreshold: CGFloat =  110
    private let editThreshold: CGFloat    = -90
    private let shareThreshold: CGFloat   =  90

    var body: some View {
        ZStack(alignment: .leading) {
            // Action hint revealed as the card slides
            activeHint

            TaskContentView(
                task: task,
                dragOffset: dragOffset,
                isCrumpled: false,
                isDragging: isDragging,
                showingAction: anyActionReady,
                onStatusChange: onStatusChange,
                occurrenceDate: occurrenceDate,
                isFutureHabit: isFutureHabit
            )
            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.78), value: dragOffset)
            .gesture(createDragGesture())
            .contextMenu {
                if !isFutureHabit {
                    Button("Edit") { onEdit() }
                    Button("Complete") { onComplete() }
                    Button("Delete", role: .destructive) { onDelete() }
                    Button { presentShareSheet() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if isFutureHabit {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(minWidth: 350, maxWidth: 350, minHeight: 100)
                    .onTapGesture { showFutureHabitAlert = true }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .alert("Not Yet!", isPresented: $showFutureHabitAlert) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("This habit isn't available yet. Check back next time!")
        }
    }

    private var anyActionReady: Bool {
        readyToDelete || readyToComplete || readyToEdit || readyToShare
    }

    @ViewBuilder
    private var activeHint: some View {
        if readyToDelete {
            ActionHintView(icon: "trash.fill", label: "Delete", tint: .red, isTriggered: readyToDelete)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToComplete {
            ActionHintView(icon: "checkmark.circle.fill", label: "Complete", tint: .green, isTriggered: readyToComplete)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToEdit {
            ActionHintView(icon: "pencil.circle.fill", label: "Edit", tint: .blue, isTriggered: readyToEdit)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if readyToShare {
            ActionHintView(icon: "square.and.arrow.up.fill", label: "Share", tint: .purple, isTriggered: readyToShare)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    // MARK: - Gesture

    private func createDragGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in handleDragChanged(value) }
            .onEnded { value in handleDragEnded(value) }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isFutureHabit else {
            showFutureHabitAlert = true
            return
        }
        // Dampen translation beyond thresholds so the card resists over-pull
        var t = value.translation
        if t.width < deleteThreshold  { t.width  = deleteThreshold  + (t.width  - deleteThreshold)  * 0.3 }
        if t.width > completeThreshold { t.width  = completeThreshold + (t.width  - completeThreshold) * 0.3 }
        if t.height < editThreshold   { t.height = editThreshold   + (t.height - editThreshold)   * 0.3 }
        if t.height > shareThreshold  { t.height = shareThreshold  + (t.height - shareThreshold)  * 0.3 }

        dragOffset = t
        isDragging = true

        withAnimation(.easeOut(duration: 0.15)) {
            readyToDelete  = value.translation.width  < deleteThreshold
            readyToComplete = value.translation.width  > completeThreshold
            readyToEdit    = !readyToDelete && !readyToComplete && value.translation.height < editThreshold
            readyToShare   = !readyToDelete && !readyToComplete && value.translation.height > shareThreshold
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        guard !isFutureHabit else { return }
        isDragging = false
        if      readyToDelete   { performDeleteAction() }
        else if readyToComplete { performCompleteAction() }
        else if readyToEdit     { performEditAction() }
        else if readyToShare    { performShareAction() }
        else                    { snapBack() }
    }

    private func performDeleteAction() {
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: -500, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDelete(); resetAllStates() }
    }

    private func performCompleteAction() {
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(width: 500, height: dragOffset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onComplete(); resetAllStates() }
    }

    private func performEditAction() {
        snapBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onEdit() }
    }

    private func performShareAction() {
        snapBack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { presentShareSheet() }
    }

    private func snapBack() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { resetAllStates() }
    }

    private func resetAllStates() {
        dragOffset = .zero
        readyToDelete = false; readyToComplete = false
        readyToEdit = false; readyToShare = false
    }

    private func presentShareSheet() {
        let dueText: String
        if let due = task.dueDate {
            dueText = due.formatted(date: .abbreviated, time: .shortened)
        } else {
            dueText = "No due date"
        }
        let text = "📋 \(task.title)\n\(task.urgency.rawValue) · Due \(dueText)"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let popover = vc.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(vc, animated: true)
    }
}

// MARK: - Animation Modifier

struct DragAnimationModifier: ViewModifier {
    let isDragging: Bool

    func body(content: Content) -> some View {
        content
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDragging)
    }
}

// MARK: - Task Row View

struct TaskRowView: View {
    let task: Daypilot
    let disappearingTaskID: UUID?
    @Binding var newTaskIDs: Set<UUID>
    let onDelete: (Daypilot) -> Void
    let onEdit: (Daypilot) -> Void
    let onComplete: (Daypilot) -> Void
    let onStatusChange: (Daypilot, TaskStatus) -> Void
    var occurrenceDate: Date? = nil

    private var isFutureHabit: Bool {
        guard task.type == .habit, let occ = occurrenceDate else { return false }
        return Calendar.current.compare(occ, to: Date(), toGranularity: .day) == .orderedDescending
    }

    var body: some View {
        DraggableTaskView(
            task: task,
            onDelete: { onDelete(task) },
            onEdit: { onEdit(task) },
            onComplete: { onComplete(task) },
            onStatusChange: { status in onStatusChange(task, status) },
            occurrenceDate: occurrenceDate,
            isFutureHabit: isFutureHabit
        )
        .opacity(taskOpacity)
        .animation(.easeInOut(duration: 0.6), value: newTaskIDs)
        .onAppear { handleTaskAppearance() }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var taskOpacity: Double { newTaskIDs.contains(task.uuid) ? 0 : 1 }

    private func handleTaskAppearance() {
        if newTaskIDs.contains(task.uuid) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { _ = newTaskIDs.remove(task.uuid) }
            }
        }
    }
}

// MARK: - Form Button

struct FormActionButton: View {
    let title: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .cornerRadius(10)
        }
    }
}

// MARK: - Task Form View

struct TaskFormView: View {
    @Binding var isPresented: Bool
    @Binding var toDoTitle: String
    @Binding var selectedDate: Date
    @Binding var selectedUrgency: UrgencyLevel
    @Binding var showEmptyTitleAlert: Bool
    @Binding var selectedType: TaskType
    @Binding var selectedHabitFrequency: HabitFrequency
    @Binding var selectedStatus: TaskStatus
    @Binding var selectedProgress: Int

    var onSave: () -> Void
    var isEditing: Bool = false
    var task: Daypilot? = nil

    @AppStorage("selectedTheme") private var selectedTheme = "original"
    private var theme: ThemeOption { AppThemes.find(selectedTheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Type", selection: $selectedType) {
                    ForEach(TaskType.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                if selectedType == .habit {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequency")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Button {
                                selectedHabitFrequency = freq
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(freq.rawValue).fontWeight(.medium)
                                        Text(descriptionFor(freq))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedHabitFrequency == freq {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedHabitFrequency == freq
                                              ? Color.accentColor.opacity(0.12)
                                              : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text(isEditing ? "Edit Task" : "Add a Task")
                    .font(.headline)

                if isEditing && selectedType == .task {
                    HStack {
                        Text("Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(selectedStatus.rawValue) {
                            let all = TaskStatus.allCases
                            let idx = all.firstIndex(of: selectedStatus) ?? 0
                            selectedStatus = all[(idx + 1) % all.count]
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Progress", selection: $selectedProgress) {
                            Text("0%").tag(0)
                            Text("25%").tag(25)
                            Text("50%").tag(50)
                            Text("75%").tag(75)
                            Text("100%").tag(100)
                        }
                        .pickerStyle(.segmented)
                        .tint(theme.urgencyColor(for: selectedUrgency))
                    }
                }

                TextField("Enter Task", text: $toDoTitle)
                    .textFieldStyle(.roundedBorder)

                DatePicker("Due Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])

                Picker("Urgency", selection: $selectedUrgency) {
                    ForEach(UrgencyLevel.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                FormActionButton(title: isEditing ? "Update" : "Add",
                                colors: [theme.accentColor, theme.color2, theme.color3]) {
                    handleSave()
                }
                .alert("Please enter a task name", isPresented: $showEmptyTitleAlert) {
                    Button("OK", role: .cancel) {}
                }

                FormActionButton(title: "Cancel",
                                colors: [.red.opacity(0.8), theme.accentColor.opacity(0.5)]) {
                    isPresented = false
                }
            }
            .padding()
            .padding(.bottom, 16)
        }
    }

    private func handleSave() {
        if toDoTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            showEmptyTitleAlert = true
        } else {
            onSave()
        }
    }

    private func descriptionFor(_ freq: HabitFrequency) -> String {
        switch freq {
        case .daily:         return "Every day — builds strong routines"
        case .everyOtherDay: return "Every 2 days — balanced recovery"
        case .weekly:        return "Once a week — low-frequency goals"
        }
    }
}

// MARK: - Add Task Button

struct AddTaskButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
        }
    }
}

// MARK: - Mini Calendar Strip

struct MiniCalendarStrip: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    let tasksByDay: [Date: [Daypilot]]

    private let calendar = Calendar.current

    private var days: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        var result: [Date] = []
        var day = interval.start
        while day < interval.end {
            result.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Text(displayedMonth, format: .dateTime.year().month())
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                if selectedDate != nil {
                    Button("All") { selectedDate = nil }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                        .padding(.trailing, 8)
                }
                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        let isToday = calendar.isDateInToday(day)
                        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
                        let hasTasks = tasksByDay[calendar.startOfDay(for: day)] != nil

                        Button {
                            selectedDate = isSelected ? nil : day
                        } label: {
                            VStack(spacing: 3) {
                                Text(day.formatted(.dateTime.weekday(.narrow)))
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                                Text(day.formatted(.dateTime.day()))
                                    .font(.system(size: 15, weight: isToday ? .bold : .regular))
                                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .white))
                                Circle()
                                    .fill(hasTasks ? Color.white.opacity(isSelected ? 1 : 0.6) : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 38)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.blue : Color.white.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
    }

    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = calendar.startOfMonth(for: newDate)
            selectedDate = nil
        }
    }
}

// MARK: - Main Tasks View

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var gradientManager: SunsetGradientManager
    @State private var animatedGradient: LinearGradient = SunsetGradientManager.gradient(for: Date())
    @Query(sort: \Daypilot.dueDate, order: .forward, animation: .default) private var daypilots: [Daypilot]

    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Calendar strip state
    @State private var selectedCalendarDate: Date? = nil
    @State private var calendarDisplayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    // Form state
    @State private var isSheetShowing = false
    @State private var toDoTitle = ""
    @State private var selectedDate = Date()
    @State private var selectedUrgency = UrgencyLevel.notUrgent
    @State private var disappearingTaskID: UUID?
    @State private var editingTask: Daypilot? = nil
    @State private var isEditingSheetShowing = false
    @State private var showEmptyTitleAlert = false
    @State private var newTaskIDs: Set<UUID> = []
    @State private var selectedStatus: TaskStatus = .open
    @State private var selectedProgress: Int = 0
    @State private var selectedType: TaskType = .task
    @State private var selectedHabitFrequency: HabitFrequency = .daily
    @State private var isCanvasImportShowing = false

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()
                mainContent
            }
        }
        .onAppear {
            animatedGradient = SunsetGradientManager.gradient(for: currentDate)
            requestNotificationAuthorization()
        }
        .onReceive(timer) { input in
            withAnimation(.easeInOut(duration: 1.2)) {
                animatedGradient = SunsetGradientManager.gradient(for: input)
            }
            currentDate = input
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            withAnimation(.easeInOut(duration: 1.2)) {
                animatedGradient = SunsetGradientManager.gradient(for: currentDate)
            }
            currentDate = Date()
        }
    }

    private var backgroundGradient: some View {
        Rectangle().fill(gradientManager.gradient)
    }

    private var tasksByDay: [Date: [Daypilot]] {
        var dict: [Date: [Daypilot]] = Dictionary(
            grouping: daypilots.filter { $0.type == .task && $0.dueDate != nil }
        ) { Calendar.current.startOfDay(for: $0.dueDate!) }

        // Project each habit across its recurrence dates for the next 60 days
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let habits = daypilots.filter { $0.type == .habit && $0.dueDate != nil }
        for habit in habits {
            for offset in 0..<60 {
                guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
                if habitOccursOn(habit, date: day) {
                    let key = cal.startOfDay(for: day)
                    dict[key, default: []].append(habit)
                }
            }
        }
        return dict
    }

    private func habitOccursOn(_ task: Daypilot, date: Date) -> Bool {
        HabitScheduler.occursOn(task, date: date)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            MiniCalendarStrip(
                displayedMonth: $calendarDisplayedMonth,
                selectedDate: $selectedCalendarDate,
                tasksByDay: tasksByDay
            )

            if shouldShowEmptyState {
                emptyStateView
            } else {
                tasksList
            }
        }
        .navigationTitle("Today's Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isCanvasImportShowing = true
                } label: {
                    Image(systemName: "books.vertical")
                        .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                AddTaskButton {
                    resetForm()
                    isSheetShowing.toggle()
                }
            }
        }
        .sheet(isPresented: $isSheetShowing) {
            addTaskSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingSheetShowing) {
            editTaskSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isCanvasImportShowing) {
            CanvasView()
                .environmentObject(gradientManager)
        }
    }

    private var shouldShowEmptyState: Bool {
        filteredAndSortedDaypilots.isEmpty && disappearingTaskID == nil
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            selectedCalendarDate != nil ? "No tasks for this day" : "Nothing to do yet!",
            systemImage: selectedCalendarDate != nil ? "calendar.badge.exclamationmark" : "checkmark.circle.fill"
        )
        .foregroundColor(.white)
    }

    private var tasksList: some View {
        let regularTasks = filteredAndSortedDaypilots.filter { $0.type == .task }
        let habits = filteredAndSortedDaypilots
            .filter { $0.type == .habit }
            .sorted { a, b in
                let aDone = Calendar.current.isDateInToday(a.lastCompletedDate ?? Date.distantPast)
                let bDone = Calendar.current.isDateInToday(b.lastCompletedDate ?? Date.distantPast)
                if aDone == bDone { return false }
                return !aDone
            }

        return List {
            if !regularTasks.isEmpty {
                Section("Tasks") {
                    ForEach(regularTasks, id: \.uuid) { toDo in
                        taskRow(for: toDo)
                    }
                }
            }
            if !habits.isEmpty {
                Section("Habits") {
                    ForEach(habits, id: \.uuid) { toDo in
                        taskRow(for: toDo)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func taskRow(for toDo: Daypilot) -> some View {
        let occ: Date? = (toDo.type == .habit && selectedCalendarDate != nil)
            ? selectedCalendarDate
            : nil
        TaskRowView(
            task: toDo,
            disappearingTaskID: disappearingTaskID,
            newTaskIDs: $newTaskIDs,
            onDelete: deleteTask,
            onEdit: startEditing,
            onComplete: markTaskDone,
            onStatusChange: updateTaskStatus,
            occurrenceDate: occ
        )
        .background(Color.clear)
    }

    private var filteredAndSortedDaypilots: [Daypilot] {
        let base = daypilots.filter { !$0.isCompleted || $0.uuid == disappearingTaskID }
        if let day = selectedCalendarDate {
            return base.filter { task in
                if task.type == .habit {
                    return habitOccursOn(task, date: day)
                }
                guard let due = task.dueDate else { return false }
                return Calendar.current.isDate(due, inSameDayAs: day)
            }
        }
        return base.sorted { !$0.isCompleted && $1.isCompleted }
    }

    private var addTaskSheet: some View {
        TaskFormView(
            isPresented: $isSheetShowing,
            toDoTitle: $toDoTitle,
            selectedDate: $selectedDate,
            selectedUrgency: $selectedUrgency,
            showEmptyTitleAlert: $showEmptyTitleAlert,
            selectedType: $selectedType,
            selectedHabitFrequency: $selectedHabitFrequency,
            selectedStatus: $selectedStatus,
            selectedProgress: $selectedProgress,
            onSave: addTask
        )
    }

    private var editTaskSheet: some View {
        TaskFormView(
            isPresented: $isEditingSheetShowing,
            toDoTitle: $toDoTitle,
            selectedDate: $selectedDate,
            selectedUrgency: $selectedUrgency,
            showEmptyTitleAlert: $showEmptyTitleAlert,
            selectedType: $selectedType,
            selectedHabitFrequency: $selectedHabitFrequency,
            selectedStatus: $selectedStatus,
            selectedProgress: $selectedProgress,
            onSave: updateTask,
            isEditing: true,
            task: editingTask
        )
    }

    // MARK: - Task Actions

    private func markTaskDone(_ task: Daypilot) {
        withAnimation {
            if task.type == .habit {
                task.streakCount = HabitScheduler.updatedStreak(for: task)
                task.lastCompletedDate = Date()
                task.isCompleted = false
                cancelNotification(for: task)
                scheduleHabitNotifications(for: task)
            } else {
                task.isCompleted = true
                disappearingTaskID = task.uuid
                cancelNotification(for: task)
            }
            try? modelContext.save()
        }

        if task.type == .task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { disappearingTaskID = nil }
            }
        }
    }

    private func deleteTask(_ task: Daypilot) {
        withAnimation {
            cancelNotification(for: task)
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    private func startEditing(_ task: Daypilot) {
        editingTask = task
        toDoTitle = task.title
        selectedDate = task.dueDate ?? Date()
        selectedUrgency = task.urgency
        selectedStatus = task.status
        let steps = [0, 25, 50, 75, 100]
        selectedProgress = steps.min(by: { abs($0 - task.progress) < abs($1 - task.progress) }) ?? 0
        selectedType = task.type
        selectedHabitFrequency = task.habitFrequency
        isEditingSheetShowing = true
    }

    private func resetForm() {
        toDoTitle = ""
        selectedDate = Date()
        selectedUrgency = .notUrgent
        editingTask = nil
        selectedStatus = .open
        selectedProgress = 0
        selectedType = .task
        selectedHabitFrequency = .daily
    }

    private func addTask() {
        guard !toDoTitle.trimmingCharacters(in: .whitespaces).isEmpty else {
            showEmptyTitleAlert = true
            return
        }
        let newTask = Daypilot(
            title: toDoTitle,
            isCompleted: false,
            dueDate: selectedDate,
            urgency: selectedUrgency,
            status: selectedStatus,
            progress: selectedProgress,
            type: selectedType,
            habitFrequency: selectedHabitFrequency
        )
        modelContext.insert(newTask)
        do {
            try modelContext.save()
            scheduleHabitNotifications(for: newTask)
            newTaskIDs.insert(newTask.uuid)
            isSheetShowing = false
        } catch {
            print("Failed to save new task: \(error)")
        }
    }

    private func updateTask() {
        guard let task = editingTask else { return }
        cancelNotification(for: task)
        task.title = toDoTitle
        task.dueDate = selectedDate
        task.urgency = selectedUrgency
        task.status = selectedStatus
        task.progress = selectedProgress
        task.type = selectedType
        task.habitFrequency = selectedHabitFrequency
        do {
            try modelContext.save()
            scheduleHabitNotifications(for: task)
            isEditingSheetShowing = false
            editingTask = nil
        } catch {
            print("Failed to update task: \(error)")
        }
    }

    private func updateTaskStatus(_ task: Daypilot, _ status: TaskStatus) {
        task.status = status
        try? modelContext.save()
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error { print("Notification permission denied: \(error.localizedDescription)") }
        }
    }

    private func scheduleHabitNotifications(for task: Daypilot) {
        HabitScheduler.schedule(task)
    }

    private func cancelNotification(for task: Daypilot) {
        HabitScheduler.cancel(task)
    }
}
