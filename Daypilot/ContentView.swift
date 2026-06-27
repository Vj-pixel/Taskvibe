import SwiftUI

struct ContentView: View {
    @AppStorage("darkModeEnabled")    private var darkModeEnabled    = true
    @AppStorage("selectedFontDesign") private var selectedFontDesign = "default"
    @AppStorage("textSizeOption")     private var textSizeOption     = "default"
    @AppStorage("tabOrder")           private var tabOrder           = "tasks,canvas,settings,profile"
    @AppStorage("pomodoroPlacement")  private var pomodoroPlacement  = "corner"

    private var fontDesign: Font.Design {
        switch selectedFontDesign {
        case "rounded":    return .rounded
        case "serif":      return .serif
        case "monospaced": return .monospaced
        default:           return .default
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch textSizeOption {
        case "small":  return .small
        case "large":  return .xLarge
        case "xlarge": return .xxLarge
        default:       return .large
        }
    }

    private var orderedTabIds: [String] {
        var ids = tabOrder.split(separator: ",").map(String.init)
        for id in ["tasks", "canvas", "settings", "profile"] where !ids.contains(id) {
            ids.append(id)
        }
        if pomodoroPlacement == "tab" {
            if !ids.contains("focus") { ids.append("focus") }
        } else {
            ids.removeAll { $0 == "focus" }
        }
        return ids
    }

    var body: some View {
        TabView {
            ForEach(orderedTabIds, id: \.self) { id in
                tabContent(for: id)
                    .tabItem { Label(tabLabel(for: id), systemImage: tabIcon(for: id)) }
                    .tag(id)
            }
        }
        .fontDesign(fontDesign)
        .dynamicTypeSize(dynamicTypeSize)
        .tint(.white)
        .toolbarBackground(.hidden, for: .tabBar)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }

    @ViewBuilder
    private func tabContent(for id: String) -> some View {
        switch id {
        case "tasks":    TasksView()
        case "canvas":   CanvasView()
        case "settings": SettingsView(darkModeEnabled: $darkModeEnabled)
        case "profile":  ProfileView()
        case "focus":    PomodoroView()
        default:         EmptyView()
        }
    }

    private func tabLabel(for id: String) -> String {
        switch id {
        case "tasks":    return "Tasks"
        case "canvas":   return "Canvas"
        case "settings": return "Settings"
        case "profile":  return "Profile"
        case "focus":    return "Focus"
        default:         return id.capitalized
        }
    }

    private func tabIcon(for id: String) -> String {
        switch id {
        case "tasks":    return "checklist"
        case "canvas":   return "books.vertical"
        case "settings": return "gear"
        case "profile":  return "person.circle"
        case "focus":    return "timer"
        default:         return "circle"
        }
    }
}
