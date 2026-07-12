import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @AppStorage("darkModeEnabled")    private var darkModeEnabled    = true
    @AppStorage("selectedFontDesign") private var selectedFontDesign = "default"
    @AppStorage("selectedFontWeight") private var selectedFontWeight = "regular"
    @AppStorage("textSizeOption")     private var textSizeOption     = "default"
    @AppStorage("tabOrder")           private var tabOrder           = "tasks,canvas,settings,profile"
    @AppStorage("pomodoroPlacement")  private var pomodoroPlacement  = "corner"
    @AppStorage("appLockEnabled")     private var appLockEnabled     = false
    @AppStorage("selectedTheme")      private var selectedTheme      = "original"
    @State private var selectedTab    = "tasks"
    @State private var isLocked       = false
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabPill

    private var fontDesign: Font.Design {
        switch selectedFontDesign {
        case "rounded":    return .rounded
        case "serif":      return .serif
        case "monospaced": return .monospaced
        default:           return .default
        }
    }

    private var customFontName: String? {
        switch selectedFontDesign {
        case "avenirnext":  return "AvenirNext-Regular"
        case "georgia":     return "Georgia"
        case "baskerville": return "Baskerville"
        case "didot":       return "Didot"
        case "typewriter":  return "AmericanTypewriter"
        case "gillsans":    return "GillSans"
        default:            return nil
        }
    }

    private var fontWeight: Font.Weight {
        switch selectedFontWeight {
        case "light":     return .light
        case "semibold":  return .semibold
        default:          return .regular
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
        TabView(selection: $selectedTab) {
            ForEach(orderedTabIds, id: \.self) { id in
                tabContent(for: id)
                    .tabItem { Label(tabLabel(for: id), systemImage: tabIcon(for: id)) }
                    .tag(id)
            }
        }
        .fontDesign(fontDesign)
        .fontWeight(fontWeight)
        .dynamicTypeSize(dynamicTypeSize)
        .applyCustomFont(customFontName)
        .tint(.white)
        .toolbarBackground(.hidden, for: .tabBar)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .overlay {
            if isLocked && appLockEnabled {
                LockScreenOverlay(theme: AppThemes.find(selectedTheme), onUnlock: authenticate)
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, appLockEnabled { isLocked = true }
            else if phase == .active, appLockEnabled, isLocked { authenticate() }
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var error: NSError?
        let policy: LAPolicy = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        ctx.evaluatePolicy(policy, localizedReason: "Unlock Daypilot") { success, _ in
            DispatchQueue.main.async { if success { isLocked = false } }
        }
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

private struct CustomTabBar: View {
    let tabs: [String]
    @Binding var selected: String
    let theme: ThemeOption
    var namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { id in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        selected = id
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon(id))
                            .font(.system(size: 19, weight: .semibold))
                        Text(label(id))
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(selected == id ? .white : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selected == id {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.18))
                                .matchedGeometryEffect(id: "tabPill", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func icon(_ id: String) -> String {
        switch id {
        case "tasks":    return "checklist"
        case "canvas":   return "books.vertical"
        case "settings": return "gear"
        case "profile":  return "person.circle"
        case "focus":    return "timer"
        default:         return "circle"
        }
    }

    private func label(_ id: String) -> String {
        switch id {
        case "tasks":    return "Tasks"
        case "canvas":   return "Canvas"
        case "settings": return "Settings"
        case "profile":  return "Profile"
        case "focus":    return "Focus"
        default:         return id.capitalized
        }
    }
}

private extension View {
    @ViewBuilder
    func applyCustomFont(_ name: String?) -> some View {
        if let name {
            self.environment(\.font, .custom(name, size: 17, relativeTo: .body))
        } else {
            self
        }
    }
}

private struct LockScreenOverlay: View {
    let theme: ThemeOption
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.04), theme.color1.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "metronome.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Daypilot")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Button(action: onUnlock) {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                        Text("Unlock")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
