// ThemePickerView.swift

import SwiftUI
import Combine

// MARK: - Theme Model

struct ThemeOption: Identifiable {
    let id: String
    let name: String
    let color1: Color
    let color2: Color
    let color3: Color
    let sunriseColors: [Color]
    let dayColors: [Color]
    let sunsetColors: [Color]
    let nightColors: [Color]
    let urgentColor: Color
    let kindaUrgentColor: Color
    let notUrgentColor: Color
    var accentColor: Color { color1 }

    func urgencyColor(for level: UrgencyLevel) -> Color {
        switch level {
        case .urgent:      return urgentColor
        case .kindaUrgent: return kindaUrgentColor
        case .notUrgent:   return notUrgentColor
        }
    }
}

// MARK: - Theme Library

struct AppThemes {
    static let all: [ThemeOption] = [
        // ── Original: bold purple/blue sky, vivid at all hours ──
        ThemeOption(
            id: "original", name: "Original",
            color1: c(0.60,0.10,0.90), color2: c(0.30,0.10,0.80), color3: c(0.10,0.40,1.00),
            sunriseColors: [c(0.90,0.20,0.50), c(1.00,0.55,0.20), c(0.70,0.10,0.80)],
            dayColors:     [c(0.20,0.45,1.00), c(0.00,0.80,1.00), c(0.40,0.10,0.95)],
            sunsetColors:  [c(0.80,0.10,0.60), c(1.00,0.40,0.10), c(0.50,0.00,0.90)],
            nightColors:   [c(0.40,0.00,0.80), c(0.60,0.10,1.00), c(0.20,0.00,0.55)],
            urgentColor: .red, kindaUrgentColor: .orange, notUrgentColor: c(0.10,0.90,1.00)
        ),
        // ── Light: warm sky blues and soft corals, bright even at night ──
        ThemeOption(
            id: "light", name: "Light",
            color1: c(0.40,0.70,1.00), color2: c(1.00,0.55,0.65), color3: c(0.80,0.90,1.00),
            sunriseColors: [c(1.00,0.80,0.55), c(1.00,0.65,0.75), c(0.60,0.80,1.00)],
            dayColors:     [c(0.45,0.75,1.00), c(0.70,0.92,1.00), c(0.90,0.75,1.00)],
            sunsetColors:  [c(1.00,0.45,0.55), c(1.00,0.65,0.30), c(0.80,0.50,1.00)],
            nightColors:   [c(0.30,0.40,0.90), c(0.55,0.50,1.00), c(0.70,0.65,1.00)],
            urgentColor: c(0.95,0.35,0.35), kindaUrgentColor: c(1.00,0.72,0.20), notUrgentColor: c(0.20,0.80,0.65)
        ),
        // ── Midnight: deep navy cosmos, stars at night ──
        ThemeOption(
            id: "midnight", name: "Midnight",
            color1: c(0.10,0.15,0.55), color2: c(0.20,0.20,0.70), color3: c(0.35,0.30,0.85),
            sunriseColors: [c(0.10,0.10,0.45), c(0.25,0.15,0.60), c(0.05,0.05,0.35)],
            dayColors:     [c(0.12,0.18,0.60), c(0.20,0.25,0.75), c(0.08,0.12,0.50)],
            sunsetColors:  [c(0.20,0.10,0.55), c(0.35,0.10,0.65), c(0.10,0.05,0.45)],
            nightColors:   [c(0.05,0.05,0.35), c(0.12,0.12,0.55), c(0.20,0.15,0.65)],
            urgentColor: c(1.00,0.30,0.40), kindaUrgentColor: c(1.00,0.82,0.20), notUrgentColor: c(0.35,0.30,0.85)
        ),
        // ── Paper: warm vintage parchment, sepia at night ──
        ThemeOption(
            id: "paper", name: "Paper",
            color1: c(0.85,0.65,0.35), color2: c(0.95,0.82,0.60), color3: c(0.70,0.50,0.25),
            sunriseColors: [c(1.00,0.88,0.62), c(1.00,0.78,0.45), c(0.95,0.82,0.55)],
            dayColors:     [c(0.98,0.90,0.72), c(0.90,0.82,0.60), c(1.00,0.93,0.75)],
            sunsetColors:  [c(0.90,0.62,0.28), c(0.80,0.50,0.18), c(0.70,0.45,0.20)],
            nightColors:   [c(0.40,0.25,0.10), c(0.55,0.35,0.15), c(0.30,0.18,0.07)],
            urgentColor: c(0.80,0.15,0.10), kindaUrgentColor: c(0.85,0.65,0.35), notUrgentColor: c(0.35,0.60,0.25)
        ),
        // ── Cyberpunk: electric neons searing against dark grids ──
        ThemeOption(
            id: "cyberpunk", name: "Cyberpunk",
            color1: c(0.00,1.00,0.40), color2: c(1.00,0.95,0.00), color3: c(0.00,0.95,1.00),
            sunriseColors: [c(0.00,0.90,0.20), c(0.80,1.00,0.00), c(0.05,0.08,0.15)],
            dayColors:     [c(0.00,1.00,0.45), c(0.00,0.95,0.95), c(0.90,1.00,0.00)],
            sunsetColors:  [c(1.00,0.00,0.90), c(0.60,0.00,1.00), c(0.10,0.10,0.20)],
            nightColors:   [c(0.00,0.90,0.30), c(1.00,0.00,0.70), c(0.05,0.05,0.18)],
            urgentColor: c(1.00,0.10,0.65), kindaUrgentColor: c(1.00,0.95,0.00), notUrgentColor: c(0.00,1.00,0.40)
        ),
        // ── Retrowave: hot pink & violet chrome, neon sunset forever ──
        ThemeOption(
            id: "retrowave", name: "Retrowave",
            color1: c(1.00,0.10,0.65), color2: c(0.70,0.00,1.00), color3: c(0.10,0.50,1.00),
            sunriseColors: [c(1.00,0.15,0.65), c(1.00,0.50,0.10), c(0.55,0.00,0.80)],
            dayColors:     [c(0.70,0.00,1.00), c(0.15,0.50,1.00), c(1.00,0.00,0.80)],
            sunsetColors:  [c(1.00,0.05,0.55), c(0.65,0.00,0.85), c(1.00,0.40,0.00)],
            nightColors:   [c(0.80,0.00,0.55), c(0.40,0.00,0.80), c(1.00,0.10,0.50)],
            urgentColor: c(1.00,0.10,0.65), kindaUrgentColor: c(0.70,0.00,1.00), notUrgentColor: c(0.10,0.50,1.00)
        ),
        // ── Forest: lush emerald canopy, fireflies at night ──
        ThemeOption(
            id: "forest", name: "Forest",
            color1: c(0.10,0.65,0.20), color2: c(0.25,0.75,0.15), color3: c(0.50,0.80,0.10),
            sunriseColors: [c(0.60,0.88,0.25), c(0.35,0.70,0.15), c(0.80,0.95,0.35)],
            dayColors:     [c(0.12,0.68,0.18), c(0.05,0.55,0.08), c(0.35,0.78,0.12)],
            sunsetColors:  [c(0.25,0.55,0.10), c(0.40,0.42,0.05), c(0.18,0.48,0.10)],
            nightColors:   [c(0.08,0.40,0.10), c(0.15,0.55,0.15), c(0.05,0.28,0.06)],
            urgentColor: c(0.85,0.15,0.10), kindaUrgentColor: c(0.90,0.68,0.15), notUrgentColor: c(0.10,0.65,0.20)
        ),
        // ── Ocean: tropical reef to abyssal blue, vivid bioluminescence at night ──
        ThemeOption(
            id: "ocean", name: "Ocean",
            color1: c(0.00,0.55,0.95), color2: c(0.00,0.80,0.90), color3: c(0.30,0.90,0.95),
            sunriseColors: [c(0.45,0.90,0.95), c(0.00,0.75,0.90), c(0.65,0.95,1.00)],
            dayColors:     [c(0.00,0.55,0.95), c(0.00,0.82,1.00), c(0.20,0.85,0.95)],
            sunsetColors:  [c(0.00,0.40,0.80), c(0.15,0.25,0.70), c(0.00,0.55,0.85)],
            nightColors:   [c(0.00,0.25,0.70), c(0.00,0.45,0.85), c(0.00,0.18,0.55)],
            urgentColor: c(0.95,0.30,0.25), kindaUrgentColor: c(1.00,0.78,0.15), notUrgentColor: c(0.00,0.55,0.95)
        ),
        // ── Ume: Japanese plum blossom — rose petal dawn to cherry night ──
        ThemeOption(
            id: "ume", name: "Ume",
            color1: c(1.00,0.45,0.70), color2: c(0.75,0.15,0.50), color3: c(0.95,0.70,0.85),
            sunriseColors: [c(1.00,0.78,0.85), c(1.00,0.60,0.72), c(0.98,0.85,0.92)],
            dayColors:     [c(1.00,0.50,0.75), c(0.90,0.60,0.88), c(0.80,0.50,0.85)],
            sunsetColors:  [c(0.75,0.15,0.48), c(0.90,0.20,0.60), c(0.55,0.08,0.38)],
            nightColors:   [c(0.55,0.05,0.30), c(0.75,0.10,0.45), c(0.40,0.03,0.22)],
            urgentColor: c(0.75,0.10,0.30), kindaUrgentColor: c(1.00,0.45,0.70), notUrgentColor: c(0.60,0.90,0.85)
        ),
        // ── Copper: burnished metal — from golden forge to dark bronze ──
        ThemeOption(
            id: "copper", name: "Copper",
            color1: c(0.85,0.52,0.18), color2: c(0.65,0.35,0.08), color3: c(1.00,0.72,0.28),
            sunriseColors: [c(1.00,0.75,0.25), c(0.95,0.62,0.18), c(0.80,0.55,0.12)],
            dayColors:     [c(0.88,0.58,0.22), c(0.75,0.48,0.15), c(1.00,0.70,0.28)],
            sunsetColors:  [c(0.65,0.35,0.08), c(0.55,0.26,0.05), c(0.75,0.40,0.12)],
            nightColors:   [c(0.40,0.18,0.04), c(0.60,0.28,0.08), c(0.30,0.12,0.02)],
            urgentColor: c(0.80,0.15,0.10), kindaUrgentColor: c(0.85,0.52,0.18), notUrgentColor: c(0.25,0.72,0.45)
        ),
        // ── Terminal: hacker green phosphor glow, bright even in the dark ──
        ThemeOption(
            id: "terminal", name: "Terminal",
            color1: c(0.00,1.00,0.35), color2: c(0.00,0.80,0.20), color3: c(0.40,1.00,0.10),
            sunriseColors: [c(0.00,0.65,0.15), c(0.20,0.90,0.00), c(0.02,0.08,0.04)],
            dayColors:     [c(0.00,1.00,0.40), c(0.30,0.95,0.00), c(0.00,0.70,0.20)],
            sunsetColors:  [c(0.00,0.80,0.25), c(0.50,1.00,0.00), c(0.04,0.08,0.04)],
            nightColors:   [c(0.00,0.80,0.25), c(0.00,0.50,0.12), c(0.02,0.12,0.04)],
            urgentColor: c(0.85,0.15,0.10), kindaUrgentColor: c(0.90,0.90,0.20), notUrgentColor: c(0.00,1.00,0.35)
        ),
        // ── Organs: visceral crimson — beating red at every hour ──
        ThemeOption(
            id: "organs", name: "Organs",
            color1: c(0.85,0.08,0.08), color2: c(1.00,0.15,0.10), color3: c(0.65,0.04,0.04),
            sunriseColors: [c(0.80,0.10,0.08), c(0.55,0.05,0.05), c(1.00,0.18,0.08)],
            dayColors:     [c(0.90,0.12,0.10), c(0.70,0.08,0.06), c(1.00,0.18,0.12)],
            sunsetColors:  [c(0.65,0.06,0.06), c(0.45,0.03,0.03), c(0.80,0.08,0.06)],
            nightColors:   [c(0.45,0.04,0.04), c(0.65,0.06,0.05), c(0.30,0.02,0.02)],
            urgentColor: c(0.85,0.08,0.08), kindaUrgentColor: c(1.00,0.50,0.10), notUrgentColor: c(0.20,0.70,0.35)
        ),
        // ── Lavender: dreamy violet fields, purple aurora at night ──
        ThemeOption(
            id: "lavender", name: "Lavender",
            color1: c(0.72,0.58,1.00), color2: c(0.55,0.38,0.90), color3: c(0.85,0.75,1.00),
            sunriseColors: [c(0.88,0.80,1.00), c(0.75,0.62,0.98), c(0.95,0.85,1.00)],
            dayColors:     [c(0.65,0.52,0.95), c(0.55,0.60,1.00), c(0.72,0.62,0.98)],
            sunsetColors:  [c(0.58,0.32,0.90), c(0.72,0.28,0.80), c(0.45,0.22,0.72)],
            nightColors:   [c(0.40,0.18,0.75), c(0.58,0.25,0.88), c(0.28,0.12,0.60)],
            urgentColor: c(1.00,0.30,0.55), kindaUrgentColor: c(0.72,0.58,1.00), notUrgentColor: c(0.45,0.90,0.80)
        ),
        // ── GPT: lush emerald intelligence — bright jade ──
        ThemeOption(
            id: "gpt", name: "GPT",
            color1: c(0.06,0.78,0.60), color2: c(0.00,0.60,0.45), color3: c(0.15,0.88,0.70),
            sunriseColors: [c(0.25,0.88,0.68), c(0.10,0.65,0.50), c(0.35,0.92,0.72)],
            dayColors:     [c(0.06,0.78,0.60), c(0.12,0.68,0.55), c(0.20,0.85,0.65)],
            sunsetColors:  [c(0.03,0.55,0.40), c(0.02,0.38,0.28), c(0.06,0.50,0.38)],
            nightColors:   [c(0.02,0.35,0.25), c(0.05,0.50,0.38), c(0.00,0.25,0.18)],
            urgentColor: c(1.00,0.35,0.25), kindaUrgentColor: c(1.00,0.82,0.20), notUrgentColor: c(0.06,0.78,0.60)
        ),
        // ── Claude: warm terracotta sunrise to burnt ember night ──
        ThemeOption(
            id: "claude", name: "Claude",
            color1: c(0.90,0.52,0.35), color2: c(1.00,0.65,0.42), color3: c(0.75,0.38,0.22),
            sunriseColors: [c(1.00,0.75,0.42), c(1.00,0.60,0.30), c(0.90,0.52,0.20)],
            dayColors:     [c(0.92,0.55,0.38), c(0.80,0.45,0.28), c(1.00,0.65,0.42)],
            sunsetColors:  [c(0.75,0.35,0.20), c(0.60,0.28,0.14), c(0.85,0.38,0.22)],
            nightColors:   [c(0.55,0.22,0.10), c(0.72,0.32,0.15), c(0.40,0.15,0.06)],
            urgentColor: c(0.90,0.35,0.15), kindaUrgentColor: c(1.00,0.65,0.42), notUrgentColor: c(0.95,0.92,0.88)
        ),
        // ── Cute: bubblegum pastels, warm cotton candy evening ──
        ThemeOption(
            id: "cute", name: "Cute",
            color1: c(1.00,0.68,0.82), color2: c(0.68,0.95,0.82), color3: c(0.68,0.85,1.00),
            sunriseColors: [c(1.00,0.85,0.68), c(1.00,0.75,0.80), c(1.00,0.88,0.82)],
            dayColors:     [c(0.68,0.85,1.00), c(0.68,0.95,0.82), c(0.85,0.75,1.00)],
            sunsetColors:  [c(1.00,0.58,0.72), c(1.00,0.68,0.48), c(0.98,0.65,0.82)],
            nightColors:   [c(0.65,0.30,0.78), c(0.82,0.25,0.60), c(0.50,0.22,0.68)],
            urgentColor: c(1.00,0.35,0.55), kindaUrgentColor: c(1.00,0.68,0.82), notUrgentColor: c(0.68,0.95,0.82)
        )
    ]

    static func find(_ id: String) -> ThemeOption {
        all.first { $0.id == id } ?? all[0]
    }
}

// Shorthand color constructor for readability above
private func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
    Color(red: r, green: g, blue: b)
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: ThemeOption
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(theme.color3)
                    .frame(width: 30, height: 30)
                    .offset(x: 19)
                Circle()
                    .fill(theme.color2)
                    .frame(width: 30, height: 30)
                Circle()
                    .fill(theme.color1)
                    .frame(width: 30, height: 30)
                    .offset(x: -19)
            }
            .frame(width: 72, height: 30)

            Text(theme.name)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.17, green: 0.17, blue: 0.19))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? theme.color1 : Color.clear, lineWidth: 2.5)
        )
        .shadow(
            color: isSelected ? theme.color1.opacity(0.6) : .clear,
            radius: 10, x: 0, y: 0
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"
    @EnvironmentObject private var gradientManager: SunsetGradientManager

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppThemes.all) { theme in
                        ThemeCard(theme: theme, isSelected: selectedTheme == theme.id)
                            .onTapGesture {
                                selectedTheme = theme.id
                                gradientManager.updateGradient()
                            }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Themes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        ThemePickerView()
            .environmentObject(SunsetGradientManager())
    }
}
