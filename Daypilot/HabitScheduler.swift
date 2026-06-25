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
        let hourMinute = cal.dateComponents([.hour, .minute], from: startDate)

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
            for n in 0..<30 {
                guard let fireDate = cal.date(byAdding: .day, value: n * 2, to: startDate),
                      fireDate > Date() else { continue }
                let components = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                center.add(UNNotificationRequest(
                    identifier: notifID(task, index: n),
                    content: content, trigger: trigger)) { _ in }
            }
        }
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
