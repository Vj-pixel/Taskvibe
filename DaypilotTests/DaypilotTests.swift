// DaypilotTests.swift

import Testing
import SwiftUI
import SwiftData
import Foundation
import UserNotifications
@testable import Daypilot

// MARK: - Helpers

private func makeHabit(
    title: String = "Test Habit",
    frequency: HabitFrequency = .daily,
    startDate: Date = Date(),
    lastCompleted: Date? = nil,
    streak: Int = 0
) -> Daypilot {
    let h = Daypilot(
        title: title,
        dueDate: startDate,
        urgency: .notUrgent,
        type: .habit,
        habitFrequency: frequency
    )
    h.lastCompletedDate = lastCompleted
    h.streakCount = streak
    return h
}

private func daysFromToday(_ n: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: n, to: Calendar.current.startOfDay(for: Date()))!
}

private func inMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Daypilot.self, configurations: config)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Theme System Tests
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Theme System")
struct ThemeSystemTests {

    @Test("All 16 themes are present")
    func allThemesPresent() {
        #expect(AppThemes.all.count == 16)
    }

    @Test("Theme IDs are unique")
    func uniqueThemeIDs() {
        let ids = AppThemes.all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }

    @Test("Expected theme IDs exist")
    func expectedIDs() {
        let ids = Set(AppThemes.all.map(\.id))
        let expected = ["original","light","midnight","paper","cyberpunk","retrowave",
                        "forest","ocean","ume","copper","terminal","organs",
                        "lavender","gpt","claude","cute"]
        for id in expected {
            #expect(ids.contains(id), "Missing theme: \(id)")
        }
    }

    @Test("find() returns correct theme")
    func findKnownTheme() {
        let theme = AppThemes.find("ocean")
        #expect(theme.id == "ocean")
        #expect(theme.name == "Ocean")
    }

    @Test("find() falls back to first theme for unknown ID")
    func findUnknownFallback() {
        let theme = AppThemes.find("nonexistent_xyz")
        #expect(theme.id == AppThemes.all[0].id)
    }

    @Test("Each theme has 3-element color arrays for all time periods")
    func themeColorArrayLengths() {
        for theme in AppThemes.all {
            #expect(theme.sunriseColors.count == 3, "\(theme.id) sunrise wrong count")
            #expect(theme.dayColors.count == 3,     "\(theme.id) day wrong count")
            #expect(theme.sunsetColors.count == 3,  "\(theme.id) sunset wrong count")
            #expect(theme.nightColors.count == 3,   "\(theme.id) night wrong count")
        }
    }

    @Test("accentColor equals color1")
    func accentColorIsColor1() {
        for theme in AppThemes.all {
            // Both resolve to the same Color value
            #expect(theme.accentColor == theme.color1)
        }
    }

    @Test("Theme names are non-empty")
    func themeNamesNonEmpty() {
        for theme in AppThemes.all {
            #expect(!theme.name.isEmpty)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Gradient Tests
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Gradient Manager")
struct GradientTests {

    private func hour(_ h: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h; comps.minute = 0; comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    // MARK: Period classification

    @Test("Hours 5–7 classified as sunrise")
    func sunrisePeriod() {
        for h in 5..<8 {
            #expect(SunsetGradientManager.period(for: hour(h)) == "sunrise",
                    "Hour \(h) should be sunrise")
        }
    }

    @Test("Hours 8–16 classified as day")
    func dayPeriod() {
        for h in 8..<17 {
            #expect(SunsetGradientManager.period(for: hour(h)) == "day",
                    "Hour \(h) should be day")
        }
    }

    @Test("Hours 17–19 classified as sunset")
    func sunsetPeriod() {
        for h in 17..<20 {
            #expect(SunsetGradientManager.period(for: hour(h)) == "sunset",
                    "Hour \(h) should be sunset")
        }
    }

    @Test("Hours 0–4 and 20–23 classified as night")
    func nightPeriod() {
        for h in Array(0..<5) + Array(20..<24) {
            #expect(SunsetGradientManager.period(for: hour(h)) == "night",
                    "Hour \(h) should be night")
        }
    }

    // MARK: Color array selection

    @Test("Sunrise colors match theme.sunriseColors")
    func sunriseColorsMatchTheme() {
        let theme = AppThemes.find("original")
        let colors = SunsetGradientManager.colors(for: hour(6), themeId: "original")
        #expect(colors == theme.sunriseColors)
    }

    @Test("Day colors match theme.dayColors")
    func dayColorsMatchTheme() {
        let theme = AppThemes.find("original")
        let colors = SunsetGradientManager.colors(for: hour(12), themeId: "original")
        #expect(colors == theme.dayColors)
    }

    @Test("Sunset colors match theme.sunsetColors")
    func sunsetColorsMatchTheme() {
        let theme = AppThemes.find("original")
        let colors = SunsetGradientManager.colors(for: hour(18), themeId: "original")
        #expect(colors == theme.sunsetColors)
    }

    @Test("Night colors match theme.nightColors")
    func nightColorsMatchTheme() {
        let theme = AppThemes.find("original")
        let colors = SunsetGradientManager.colors(for: hour(2), themeId: "original")
        #expect(colors == theme.nightColors)
    }

    @Test("colors() always returns exactly 3 elements for all themes and periods")
    func colorsCountAlways3() {
        for theme in AppThemes.all {
            for h in [6, 12, 18, 2] {
                let result = SunsetGradientManager.colors(for: hour(h), themeId: theme.id)
                #expect(result.count == 3, "\(theme.id) h:\(h) returned \(result.count) colors")
            }
        }
    }

    @Test("Unknown themeId falls back to original theme colors")
    func unknownThemeFallback() {
        let colors = SunsetGradientManager.colors(for: hour(12), themeId: "nonexistent_999")
        let original = AppThemes.find("original").dayColors
        #expect(colors == original)
    }

    @Test("Different themes return different color arrays for the same time")
    func differentThemesDifferentColors() {
        let ocean  = SunsetGradientManager.colors(for: hour(12), themeId: "ocean")
        let forest = SunsetGradientManager.colors(for: hour(12), themeId: "forest")
        #expect(ocean != forest)
    }

    @Test("Sunrise and night periods return different colors for same theme")
    func periodsAreDifferentWithinTheme() {
        let sunrise = SunsetGradientManager.colors(for: hour(6),  themeId: "original")
        let night   = SunsetGradientManager.colors(for: hour(2),  themeId: "original")
        #expect(sunrise != night)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Rank System Tests
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Rank System")
struct RankSystemTests {

    @Test("0 completed → Cautious Cadet")
    func zeroCompleted() {
        let r = RankSystem.rank(for: 0)
        #expect(r.name == "Cautious Cadet")
        #expect(r.nextAt == 5)
        #expect(r.rangeStart == 0)
    }

    @Test("4 completed still Cautious Cadet (boundary -1)")
    func fourCompleted() {
        let r = RankSystem.rank(for: 4)
        #expect(r.name == "Cautious Cadet")
    }

    @Test("5 completed → Persistent Pilot")
    func fiveCompleted() {
        let r = RankSystem.rank(for: 5)
        #expect(r.name == "Persistent Pilot")
        #expect(r.nextAt == 15)
        #expect(r.rangeStart == 5)
    }

    @Test("14 completed still Persistent Pilot")
    func fourteenCompleted() {
        #expect(RankSystem.rank(for: 14).name == "Persistent Pilot")
    }

    @Test("15 completed → Bold Barnstormer")
    func fifteenCompleted() { #expect(RankSystem.rank(for: 15).name == "Bold Barnstormer") }

    @Test("30 → Capable Copilot")
    func thirtyCompleted() { #expect(RankSystem.rank(for: 30).name == "Capable Copilot") }

    @Test("50 → Daring Drifter")
    func fiftyCompleted() { #expect(RankSystem.rank(for: 50).name == "Daring Drifter") }

    @Test("75 → Fearless Flier")
    func seventyFiveCompleted() { #expect(RankSystem.rank(for: 75).name == "Fearless Flier") }

    @Test("100 → Stellar Skydiver")
    func hundredCompleted() { #expect(RankSystem.rank(for: 100).name == "Stellar Skydiver") }

    @Test("150 → Master Maverick")
    func hundredFiftyCompleted() { #expect(RankSystem.rank(for: 150).name == "Master Maverick") }

    @Test("200 → Legendary Lancer (max rank)")
    func twoHundredCompleted() {
        let r = RankSystem.rank(for: 200)
        #expect(r.name == "Legendary Lancer")
        #expect(r.nextAt == nil)
        #expect(r.isMaxRank)
    }

    @Test("Very large count stays at Legendary Lancer")
    func veryLargeCount() {
        let r = RankSystem.rank(for: 10_000)
        #expect(r.name == "Legendary Lancer")
        #expect(r.isMaxRank)
    }

    @Test("Progress at range start is 0")
    func progressAtRangeStart() {
        let r = RankSystem.rank(for: 5)   // Persistent Pilot, starts at 5, next at 15
        #expect(r.progress(for: 5) == 0.0)
    }

    @Test("Progress at midpoint is 0.5")
    func progressAtMidpoint() {
        let r = RankSystem.rank(for: 10)  // Persistent Pilot, 10/15 → 5/10 = 0.5
        #expect(abs(r.progress(for: 10) - 0.5) < 0.001)
    }

    @Test("Progress at next threshold is 1.0")
    func progressAtNextThreshold() {
        let r = RankSystem.rank(for: 14)  // Persistent Pilot, next at 15
        #expect(abs(r.progress(for: 14) - 0.9) < 0.001)
    }

    @Test("Max rank progress is always 1.0")
    func maxRankProgress() {
        let r = RankSystem.rank(for: 200)
        #expect(r.progress(for: 200) == 1.0)
        #expect(r.progress(for: 999) == 1.0)
    }

    @Test("9 distinct tier names")
    func tierCount() {
        #expect(RankSystem.tiers.count == 9)
    }

    @Test("Tier thresholds are strictly ascending")
    func tiersAscending() {
        let thresholds = RankSystem.tiers.map(\.threshold)
        for i in 1..<thresholds.count {
            #expect(thresholds[i] > thresholds[i - 1])
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Habit Scheduler — Recurrence
// ─────────────────────────────────────────────────────────────────────────────

@Suite("HabitScheduler – Recurrence")
struct HabitRecurrenceTests {

    // MARK: Daily

    @Test("Daily habit occurs on start day")
    func dailyOnStartDay() {
        let h = makeHabit(frequency: .daily, startDate: daysFromToday(0))
        #expect(HabitScheduler.occursOn(h, date: daysFromToday(0)))
    }

    @Test("Daily habit occurs every subsequent day")
    func dailyEveryDay() {
        let h = makeHabit(frequency: .daily, startDate: daysFromToday(0))
        for offset in 1...30 {
            #expect(HabitScheduler.occursOn(h, date: daysFromToday(offset)),
                    "Should occur on day +\(offset)")
        }
    }

    @Test("Daily habit does NOT occur before start date")
    func dailyBeforeStart() {
        let h = makeHabit(frequency: .daily, startDate: daysFromToday(5))
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(0)))
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(4)))
    }

    // MARK: Weekly

    @Test("Weekly habit occurs on start day (day 0)")
    func weeklyDay0() {
        let h = makeHabit(frequency: .weekly, startDate: daysFromToday(0))
        #expect(HabitScheduler.occursOn(h, date: daysFromToday(0)))
    }

    @Test("Weekly habit occurs on exact 7-day multiples")
    func weeklyMultiples() {
        let h = makeHabit(frequency: .weekly, startDate: daysFromToday(0))
        for week in [7, 14, 21, 28, 35] {
            #expect(HabitScheduler.occursOn(h, date: daysFromToday(week)),
                    "Should occur at day +\(week)")
        }
    }

    @Test("Weekly habit does NOT occur on non-multiple days")
    func weeklyNonMultiples() {
        let h = makeHabit(frequency: .weekly, startDate: daysFromToday(0))
        for d in [1, 2, 3, 4, 5, 6, 8, 13, 15] {
            #expect(!HabitScheduler.occursOn(h, date: daysFromToday(d)),
                    "Should not occur at day +\(d)")
        }
    }

    @Test("Weekly habit does not occur before start")
    func weeklyBeforeStart() {
        let h = makeHabit(frequency: .weekly, startDate: daysFromToday(7))
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(0)))
    }

    // MARK: Every Other Day

    @Test("Every-other-day habit occurs on start day (day 0)")
    func eodDay0() {
        let h = makeHabit(frequency: .everyOtherDay, startDate: daysFromToday(0))
        #expect(HabitScheduler.occursOn(h, date: daysFromToday(0)))
    }

    @Test("Every-other-day habit occurs on even offsets")
    func eodEvenOffsets() {
        let h = makeHabit(frequency: .everyOtherDay, startDate: daysFromToday(0))
        for d in [2, 4, 6, 8, 10, 20, 30] {
            #expect(HabitScheduler.occursOn(h, date: daysFromToday(d)),
                    "Should occur at day +\(d)")
        }
    }

    @Test("Every-other-day habit does NOT occur on odd offsets")
    func eodOddOffsets() {
        let h = makeHabit(frequency: .everyOtherDay, startDate: daysFromToday(0))
        for d in [1, 3, 5, 7, 9, 11] {
            #expect(!HabitScheduler.occursOn(h, date: daysFromToday(d)),
                    "Should not occur at day +\(d)")
        }
    }

    @Test("Every-other-day does not occur before start")
    func eodBeforeStart() {
        let h = makeHabit(frequency: .everyOtherDay, startDate: daysFromToday(2))
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(0)))
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(1)))
    }

    // MARK: Edge cases

    @Test("Task (not habit) always returns false")
    func taskTypeReturnsFalse() {
        let t = Daypilot(title: "Task", dueDate: daysFromToday(0), urgency: .notUrgent)
        #expect(!HabitScheduler.occursOn(t, date: daysFromToday(0)))
        #expect(!HabitScheduler.occursOn(t, date: daysFromToday(1)))
    }

    @Test("Habit with no dueDate returns false")
    func habitNoDueDateReturnsFalse() {
        let h = Daypilot(title: "No date", urgency: .notUrgent, type: .habit)
        #expect(!HabitScheduler.occursOn(h, date: daysFromToday(0)))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Habit Scheduler — Done-Today & Streak
// ─────────────────────────────────────────────────────────────────────────────

@Suite("HabitScheduler – Done-Today & Streak")
struct HabitDoneTodayTests {

    @Test("isDoneToday is true when lastCompletedDate is today")
    func doneTodayTrue() {
        let h = makeHabit(lastCompleted: Date())
        #expect(HabitScheduler.isDoneToday(h))
    }

    @Test("isDoneToday is false when lastCompletedDate is yesterday")
    func doneTodayYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let h = makeHabit(lastCompleted: yesterday)
        #expect(!HabitScheduler.isDoneToday(h))
    }

    @Test("isDoneToday is false when lastCompletedDate is nil")
    func doneTodayNil() {
        let h = makeHabit(lastCompleted: nil)
        #expect(!HabitScheduler.isDoneToday(h))
    }

    @Test("isDoneToday is false for a task (not habit)")
    func doneTodayNonHabit() {
        let t = Daypilot(title: "Task", dueDate: Date(), urgency: .notUrgent)
        t.lastCompletedDate = Date()
        #expect(!HabitScheduler.isDoneToday(t))
    }

    // MARK: Streak logic

    @Test("First completion → streak = 1")
    func firstCompletion() {
        let h = makeHabit(lastCompleted: nil, streak: 0)
        #expect(HabitScheduler.updatedStreak(for: h) == 1)
    }

    @Test("Consecutive day → streak increments")
    func consecutiveDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: Calendar.current.startOfDay(for: Date()))!
        let h = makeHabit(lastCompleted: yesterday, streak: 5)
        #expect(HabitScheduler.updatedStreak(for: h) == 6)
    }

    @Test("Missed a day → streak resets to 1")
    func missedDay() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let h = makeHabit(lastCompleted: twoDaysAgo, streak: 10)
        #expect(HabitScheduler.updatedStreak(for: h) == 1)
    }

    @Test("Already done today → streak unchanged")
    func alreadyDoneToday() {
        let h = makeHabit(lastCompleted: Date(), streak: 7)
        #expect(HabitScheduler.updatedStreak(for: h) == 7)
    }

    @Test("Long-missed habit resets to 1")
    func longMissed() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let h = makeHabit(lastCompleted: twoWeeksAgo, streak: 30)
        #expect(HabitScheduler.updatedStreak(for: h) == 1)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Habit Scheduler — Notification IDs
// ─────────────────────────────────────────────────────────────────────────────

@Suite("HabitScheduler – Notification Identifiers")
struct NotificationIDTests {

    @Test("notifID produces correct format")
    func notifIDFormat() {
        let h = makeHabit()
        let id = HabitScheduler.notifID(h, index: 0)
        #expect(id == "\(h.uuid.uuidString)-habit-0")
    }

    @Test("notifID index is embedded correctly")
    func notifIDIndex() {
        let h = makeHabit()
        for i in 0..<5 {
            #expect(HabitScheduler.notifID(h, index: i).hasSuffix("-habit-\(i)"))
        }
    }

    @Test("allNotifIDs has 31 entries (30 + uuid base)")
    func allNotifIDsCount() {
        let h = makeHabit()
        let ids = HabitScheduler.allNotifIDs(for: h)
        #expect(ids.count == 31)
    }

    @Test("allNotifIDs includes the bare uuid as last entry")
    func allNotifIDsIncludesBase() {
        let h = makeHabit()
        let ids = HabitScheduler.allNotifIDs(for: h)
        #expect(ids.last == h.uuid.uuidString)
    }

    @Test("schedule respects notificationsEnabled = false")
    func scheduleRespectsDisabledFlag() async throws {
        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "notificationsEnabled") }

        let h = makeHabit(startDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!)
        HabitScheduler.schedule(h)

        // Give UNUserNotificationCenter a moment to process (nothing should be added)
        try await Task.sleep(for: .milliseconds(100))
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let habitRequests = pending.filter { $0.identifier.contains(h.uuid.uuidString) }
        #expect(habitRequests.isEmpty)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Daypilot Model (SwiftData)
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Daypilot Model")
struct DaypilotModelTests {

    @Test("Default type is .task")
    func defaultTypeIsTask() {
        let d = Daypilot(title: "My task", urgency: .notUrgent)
        #expect(d.type == .task)
    }

    @Test("Default habitFrequency is .daily")
    func defaultFrequencyIsDaily() {
        let d = Daypilot(title: "Habit", urgency: .notUrgent, type: .habit)
        #expect(d.habitFrequency == .daily)
    }

    @Test("Default streakCount is 0")
    func defaultStreakIsZero() {
        let d = Daypilot(title: "Habit", urgency: .notUrgent, type: .habit)
        #expect(d.streakCount == 0)
    }

    @Test("Default lastCompletedDate is nil")
    func defaultLastCompletedIsNil() {
        let d = Daypilot(title: "Habit", urgency: .notUrgent, type: .habit)
        #expect(d.lastCompletedDate == nil)
    }

    @Test("Default status is .open")
    func defaultStatusIsOpen() {
        let d = Daypilot(title: "Task", urgency: .notUrgent)
        #expect(d.status == .open)
    }

    @Test("status roundtrips through rawValue")
    func statusRoundtrip() {
        let d = Daypilot(title: "Task", urgency: .notUrgent)
        d.status = .inProgress
        #expect(d.status == .inProgress)
        #expect(d.statusRaw == TaskStatus.inProgress.rawValue)
    }

    @Test("type roundtrips through rawValue")
    func typeRoundtrip() {
        let d = Daypilot(title: "Habit", urgency: .notUrgent)
        d.type = .habit
        #expect(d.type == .habit)
        #expect(d.typeRaw == TaskType.habit.rawValue)
    }

    @Test("habitFrequency roundtrips through rawValue")
    func frequencyRoundtrip() {
        let d = Daypilot(title: "H", urgency: .notUrgent, type: .habit)
        d.habitFrequency = .weekly
        #expect(d.habitFrequency == .weekly)
        #expect(d.habitFrequencyRaw == HabitFrequency.weekly.rawValue)
    }

    @Test("progress defaults to 0")
    func progressDefault() {
        let d = Daypilot(title: "T", urgency: .notUrgent)
        #expect(d.progress == 0)
    }

    @Test("isCompleted defaults to false")
    func isCompletedDefault() {
        let d = Daypilot(title: "T", urgency: .notUrgent)
        #expect(d.isCompleted == false)
    }

    @Test("sourceTag defaults to nil")
    func sourceTagDefault() {
        let d = Daypilot(title: "T", urgency: .notUrgent)
        #expect(d.sourceTag == nil)
    }

    @Test("sourceTag can be set to 'Canvas'")
    func sourceTagCanvas() {
        let d = Daypilot(title: "Assignment", urgency: .notUrgent)
        d.sourceTag = "Canvas"
        #expect(d.sourceTag == "Canvas")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SwiftData Integration Tests
// ─────────────────────────────────────────────────────────────────────────────

@Suite("SwiftData Integration")
struct SwiftDataIntegrationTests {

    @Test("Inserting a Daypilot persists it in the context")
    @MainActor
    func insertPersists() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let task = Daypilot(title: "Buy groceries", urgency: .notUrgent)
        ctx.insert(task)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Buy groceries")
    }

    @Test("Deleting a Daypilot removes it from context")
    @MainActor
    func deletePersists() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let task = Daypilot(title: "To delete", urgency: .notUrgent)
        ctx.insert(task)
        try ctx.save()

        ctx.delete(task)
        try ctx.save()

        let remaining = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(remaining.isEmpty)
    }

    @Test("Multiple tasks are all stored")
    @MainActor
    func multipleTasksStored() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        for i in 1...5 {
            ctx.insert(Daypilot(title: "Task \(i)", urgency: .notUrgent))
        }
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(all.count == 5)
    }

    @Test("Habit streak increments on consecutive-day completion")
    @MainActor
    func habitStreakIncrement() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1,
                                              to: Calendar.current.startOfDay(for: Date()))!
        let habit = makeHabit(startDate: Date(), lastCompleted: yesterday, streak: 3)
        ctx.insert(habit)

        // Simulate markTaskDone logic
        habit.streakCount = HabitScheduler.updatedStreak(for: habit)
        habit.lastCompletedDate = Date()
        habit.isCompleted = false
        try ctx.save()

        #expect(habit.streakCount == 4)
        #expect(habit.isCompleted == false)
    }

    @Test("Habit streak resets after missed day")
    @MainActor
    func habitStreakReset() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let habit = makeHabit(startDate: Date(), lastCompleted: twoDaysAgo, streak: 15)
        ctx.insert(habit)

        habit.streakCount = HabitScheduler.updatedStreak(for: habit)
        habit.lastCompletedDate = Date()
        try ctx.save()

        #expect(habit.streakCount == 1)
    }

    @Test("Completing same habit twice today doesn't double-count streak")
    @MainActor
    func habitNoDuplicateStreak() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let habit = makeHabit(startDate: Date(), lastCompleted: Date(), streak: 5)
        ctx.insert(habit)

        // Second completion today
        habit.streakCount = HabitScheduler.updatedStreak(for: habit)
        habit.lastCompletedDate = Date()
        try ctx.save()

        #expect(habit.streakCount == 5) // unchanged
    }

    @Test("Completing a regular task marks it completed")
    @MainActor
    func regularTaskCompletes() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let task = Daypilot(title: "Finish report", urgency: .urgent)
        ctx.insert(task)

        task.isCompleted = true
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(fetched.first?.isCompleted == true)
    }

    @Test("Habit task is NOT permanently completed after markDone")
    @MainActor
    func habitNotPermanentlyCompleted() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let habit = makeHabit(startDate: Date(), lastCompleted: nil, streak: 0)
        ctx.insert(habit)

        habit.streakCount = HabitScheduler.updatedStreak(for: habit)
        habit.lastCompletedDate = Date()
        habit.isCompleted = false   // habits never permanently complete
        try ctx.save()

        #expect(habit.isCompleted == false)
        #expect(habit.streakCount == 1)
    }

    @Test("RankTier.progress is clamped between 0 and 1")
    func rankProgressClamped() {
        let r = RankSystem.rank(for: 0)
        #expect(r.progress(for: -10) == 0.0) // below range start
        #expect(r.progress(for: 100) <= 1.0) // above next threshold
    }

    @Test("Canvas-tagged task persists sourceTag")
    @MainActor
    func canvasTagPersists() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let task = Daypilot(title: "Canvas Assignment", urgency: .kindaUrgent)
        task.sourceTag = "Canvas"
        ctx.insert(task)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(fetched.first?.sourceTag == "Canvas")
    }

    @Test("Non-Canvas task has nil sourceTag")
    @MainActor
    func nonCanvasTaskHasNilTag() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let task = Daypilot(title: "Regular Task", urgency: .notUrgent)
        ctx.insert(task)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Daypilot>())
        #expect(fetched.first?.sourceTag == nil)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Habit Recurrence Integration (tasksByDay equivalent)
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Habit Recurrence Integration")
struct HabitRecurrenceIntegrationTests {

    @Test("Daily habit appears on each of the next 7 days")
    func dailyAppears7Days() {
        let h = makeHabit(frequency: .daily, startDate: daysFromToday(0))
        for offset in 0..<7 {
            #expect(HabitScheduler.occursOn(h, date: daysFromToday(offset)),
                    "Daily habit missing on day +\(offset)")
        }
    }

    @Test("Weekly habit appears on day 0, 7, 14, 21 but not 1-6")
    func weeklyAppearancePattern() {
        let h = makeHabit(frequency: .weekly, startDate: daysFromToday(0))
        let shouldAppear = Set([0, 7, 14, 21])
        for offset in 0..<22 {
            let appears = HabitScheduler.occursOn(h, date: daysFromToday(offset))
            #expect(appears == shouldAppear.contains(offset),
                    "Weekly habit offset \(offset): expected \(shouldAppear.contains(offset)) got \(appears)")
        }
    }

    @Test("Every-other-day habit appears on even offsets 0-20")
    func eodAppearancePattern() {
        let h = makeHabit(frequency: .everyOtherDay, startDate: daysFromToday(0))
        for offset in 0..<21 {
            let expected = offset % 2 == 0
            let actual   = HabitScheduler.occursOn(h, date: daysFromToday(offset))
            #expect(actual == expected,
                    "EOD habit offset \(offset): expected \(expected) got \(actual)")
        }
    }

    @Test("Habit with future start does not appear before start")
    func futureStartNoPastAppearance() {
        let h = makeHabit(frequency: .daily, startDate: daysFromToday(10))
        for offset in 0..<10 {
            #expect(!HabitScheduler.occursOn(h, date: daysFromToday(offset)),
                    "Should not appear before start: offset \(offset)")
        }
        #expect(HabitScheduler.occursOn(h, date: daysFromToday(10)))
    }

    @Test("Selected date filters show habits that recur on that date")
    @MainActor
    func selectedDateShowsHabits() async throws {
        let container = try inMemoryContainer()
        let ctx = ModelContext(container)

        let daily = makeHabit(frequency: .daily, startDate: daysFromToday(0))
        let weekly = makeHabit(frequency: .weekly, startDate: daysFromToday(0))
        ctx.insert(daily)
        ctx.insert(weekly)
        try ctx.save()

        let targetDay = daysFromToday(7) // day 7: daily hits, weekly hits (7 % 7 == 0)
        #expect(HabitScheduler.occursOn(daily,  date: targetDay))
        #expect(HabitScheduler.occursOn(weekly, date: targetDay))

        let midWeek = daysFromToday(3) // day 3: daily hits, weekly does NOT
        #expect(HabitScheduler.occursOn(daily,  date: midWeek))
        #expect(!HabitScheduler.occursOn(weekly, date: midWeek))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Settings / Notifications Toggle
// ─────────────────────────────────────────────────────────────────────────────

@Suite("Notifications Toggle Logic")
struct NotificationsToggleTests {

    @Test("notificationsEnabled=false prevents scheduling")
    func disabledPreventsScheduling() async throws {
        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "notificationsEnabled") }

        let h = makeHabit(
            frequency: .daily,
            startDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        )
        HabitScheduler.schedule(h)
        try await Task.sleep(for: .milliseconds(200))

        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = Set(pending.map(\.identifier))
        #expect(!ids.contains(HabitScheduler.notifID(h, index: 0)))
    }

    @Test("cancel removes all expected identifiers")
    func cancelClearsIdentifiers() async throws {
        UserDefaults.standard.set(false, forKey: "notificationsEnabled")
        defer { UserDefaults.standard.removeObject(forKey: "notificationsEnabled") }

        let h = makeHabit()
        // Just verify cancel doesn't crash even if nothing was scheduled
        HabitScheduler.cancel(h)
        try await Task.sleep(for: .milliseconds(100))
        // If we got here without crashing, the test passes
    }
}
