// SunsetGradientManager.swift

import SwiftUI
import Combine

class SunsetGradientManager: ObservableObject {
    @Published var gradient: LinearGradient
    private var timer: AnyCancellable?
    private var defaultsObserver: AnyCancellable?

    init() {
        gradient = Self.makeGradient(date: Date(), themeId: UserDefaults.standard.string(forKey: "selectedTheme") ?? "original")
        startTimer()
        observeDefaults()
    }

    // Called externally when theme changes (e.g. from ThemePickerView)
    func updateGradient() {
        let themeId = UserDefaults.standard.string(forKey: "selectedTheme") ?? "original"
        gradient = Self.makeGradient(date: Date(), themeId: themeId)
    }

    private func startTimer() {
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateGradient() }
    }

    private func observeDefaults() {
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateGradient() }
    }

    // Legacy static access used in TasksView (forwards to theme-aware version)
    static func gradient(for date: Date) -> LinearGradient {
        let themeId = UserDefaults.standard.string(forKey: "selectedTheme") ?? "original"
        return makeGradient(date: date, themeId: themeId)
    }

    static func makeGradient(date: Date, themeId: String) -> LinearGradient {
        let c = Self.colors(for: date, themeId: themeId)
        return LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Returns the raw Color array for the given time and theme — used by tests.
    static func colors(for date: Date, themeId: String) -> [Color] {
        let theme = AppThemes.find(themeId)
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:   return theme.sunriseColors
        case 8..<17:  return theme.dayColors
        case 17..<20: return theme.sunsetColors
        default:      return theme.nightColors
        }
    }

    /// Returns "sunrise", "day", "sunset", or "night" for the given time — used by tests.
    static func period(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<8:   return "sunrise"
        case 8..<17:  return "day"
        case 17..<20: return "sunset"
        default:      return "night"
        }
    }
}
