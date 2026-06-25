import SwiftUI

struct ContentView: View {
    @AppStorage("darkModeEnabled")    private var darkModeEnabled    = true
    @AppStorage("selectedFontDesign") private var selectedFontDesign = "default"
    @AppStorage("textSizeOption")     private var textSizeOption     = "default"

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

    var body: some View {
        TabView {
            Tab("Tasks", systemImage: "checklist") {
                TasksView()
            }
            Tab("Canvas", systemImage: "books.vertical") {
                CanvasView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView(darkModeEnabled: $darkModeEnabled)
            }
            Tab("Profile", systemImage: "person.circle") {
                ProfileView()
            }
        }
        .fontDesign(fontDesign)
        .dynamicTypeSize(dynamicTypeSize)
        .tint(.white)
        .toolbarBackground(.hidden, for: .tabBar)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }
}
