// HabitScheduler.swift
// Pure habit logic extracted from TasksView for testability.

import Foundation
import UserNotifications

struct HabitScheduler {

    // MARK: - Recurrence

    /// Returns true if `habit` should occur on `date` given its frequency and start date.
    static func occursOn(_ habit: Daypilot, date: Date) -> Bool {
        guard habit.type == .habit, let startDate = habit.dueDate else { return false }
        let cal = Calendar.current
        let start  = cal.startOfDay(for: startDate)
        let target = cal.startOfDay(for: date)
        guard target >= start else { return false }
        let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
        switch habit.habitFrequency {
        case .daily:         return true
        case .weekly:        return days % 7 == 0
        case .everyOtherDay: return days % 2 == 0
        }
    }

    // MARK: - Done-Today State

    /// Returns true when the habit has already been completed today.
    static func isDoneToday(_ habit: Daypilot) -> Bool {
        guard habit.type == .habit, let last = habit.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Streak Update

    /// Applies streak increment / reset logic when a habit is marked done.
    /// Returns the new streak count without mutating the model (mutation is the caller's job).
    static func updatedStreak(for habit: Daypilot) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let last = habit.lastCompletedDate else { return 1 }
        let lastDay = cal.startOfDay(for: last)
        if cal.isDate(lastDay, inSameDayAs: today) {
            return habit.streakCount          // already done today — no change
        }
        if let yesterday = cal.date(byAdding: .day, value: -1, to: today),
           cal.isDate(lastDay, inSameDayAs: yesterday) {
            return habit.streakCount + 1      // consecutive day
        }
        return 1                              // streak broken
    }

    // MARK: - Notifications

    /// Schedule notifications for a habit (respects the global notificationsEnabled flag).
    static func schedule(_ task: Daypilot,
                         center: UNUserNotificationCenter = .current()) {
        guard task.type == .habit,
              UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              let startDate = task.dueDate else { return }

        cancel(task, center: center)

        let content = UNMutableNotificationContent()
        content.title = "Habit Reminder"
        content.body  = task.title
        content.sound = .default

        let cal = Calendar.current
        let timeSource = task.reminderTime ?? startDate
        let hourMinute = cal.dateComponents([.hour, .minute], from: timeSource)

        switch task.habitFrequency {
        case .daily:
            let trigger = UNCalendarNotificationTrigger(dateMatching: hourMinute, repeats: true)
            center.add(UNNotificationRequest(
                identifier: notifID(task, index: 0),
                content: content, trigger: trigger)) { _ in }

        case .weekly:
            var components = hourMinute
            components.weekday = cal.component(.weekday, from: startDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(
                identifier: notifID(task, index: 0),
                content: content, trigger: trigger)) { _ in }

        case .everyOtherDay:
            // Always schedule 30 future occurrences starting from the next valid slot
            // relative to today, so habits created long ago still fire correctly.
            let today = cal.startOfDay(for: Date())
            let startDay = cal.startOfDay(for: startDate)
            let daysSinceStart = cal.dateComponents([.day], from: startDay, to: today).day ?? 0
            // Round up to the next even-day offset so we stay in-phase with the habit
            var offset = daysSinceStart % 2 == 0 ? daysSinceStart : daysSinceStart + 1
            var scheduled = 0
            while scheduled < 30 {
                guard let occDay = cal.date(byAdding: .day, value: offset, to: startDay) else { break }
                var fire = cal.dateComponents([.year, .month, .day], from: occDay)
                fire.hour   = hourMinute.hour
                fire.minute = hourMinute.minute
                guard let fireDate = cal.date(from: fire), fireDate > Date() else {
                    offset += 2; continue
                }
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
                center.add(UNNotificationRequest(
                    identifier: notifID(task, index: scheduled),
                    content: content, trigger: trigger)) { _ in }
                scheduled += 1
                offset += 2
            }
        }
    }

    /// Schedule a one-shot reminder notification for a regular (non-habit) task.
    static func scheduleTaskReminder(_ task: Daypilot,
                                      center: UNUserNotificationCenter = .current()) {
        guard task.type == .task,
              UserDefaults.standard.bool(forKey: "notificationsEnabled"),
              let reminderTime = task.reminderTime,
              reminderTime > Date() else { return }

        center.removePendingNotificationRequests(withIdentifiers: [task.uuid.uuidString])

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body  = task.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: task.uuid.uuidString,
                                          content: content,
                                          trigger: trigger)) { _ in }
    }

    /// Remove all pending notifications for this habit.
    static func cancel(_ task: Daypilot,
                       center: UNUserNotificationCenter = .current()) {
        let ids = (0..<30).map { notifID(task, index: $0) } + [task.uuid.uuidString]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Identifier Helpers (internal so tests can verify them)

    static func notifID(_ task: Daypilot, index: Int) -> String {
        "\(task.uuid.uuidString)-habit-\(index)"
    }

    static func allNotifIDs(for task: Daypilot) -> [String] {
        (0..<30).map { notifID(task, index: $0) } + [task.uuid.uuidString]
    }
}
