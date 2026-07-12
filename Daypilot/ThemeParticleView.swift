import SwiftUI

// MARK: - Dispatcher

struct ThemeParticleView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        Group {
            switch selectedTheme {
            case "galaxy":    GalaxyStarField()
            case "midnight":  StaticStarField()
            case "aurora":    AuroraWaves()
            case "sakura":    DriftParticles(type: .petals)
            case "ember":     DriftParticles(type: .sparks)
            case "forest":    DriftParticles(type: .leaves)
            case "ocean",
                 "tangerine": DriftParticles(type: .bubbles)
            case "cyberpunk": CyberpunkGrid()
            case "retrowave": RetrowaveScanlines()
            case "cute":      DriftParticles(type: .hearts)
            default:          EmptyView()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - View Extension

extension View {
    func themedBackground(_ gradient: LinearGradient) -> some View {
        background {
            ZStack {
                gradient
                ThemeParticleView()
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Galaxy Star Field (animated twinkling)

private struct GalaxyStarField: View {
    struct StarData {
        let x, y: Double
        let radius: CGFloat
        let baseOpacity: Double
        let speed, phase: Double
        let colorIdx: Int
    }

    @State private var stars: [StarData] = []

    private let palette: [Color] = [
        .white,
        Color(red: 0.85, green: 0.90, blue: 1.00),
        Color(red: 0.72, green: 0.82, blue: 1.00),
        Color(red: 0.95, green: 0.88, blue: 1.00)
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in stars {
                    let flicker = sin(t * s.speed + s.phase) * 0.5 + 0.5
                    let opacity = s.baseOpacity * (0.35 + 0.65 * flicker)
                    let pos = CGPoint(x: s.x * size.width, y: s.y * size.height)
                    ctx.opacity = opacity
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pos.x - s.radius, y: pos.y - s.radius,
                                               width: s.radius * 2, height: s.radius * 2)),
                        with: .color(palette[s.colorIdx])
                    )
                    if s.radius > 1.5 {
                        let gr = s.radius * 3.5
                        ctx.opacity = opacity * 0.18
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: pos.x - gr, y: pos.y - gr,
                                                   width: gr * 2, height: gr * 2)),
                            with: .color(palette[s.colorIdx])
                        )
                    }
                }
            }
        }
        .onAppear {
            guard stars.isEmpty else { return }
            stars = (0..<240).map { _ in
                StarData(
                    x: .random(in: 0...1),
                    y: .random(in: 0...1),
                    radius: .random(in: 0.4...2.4),
                    baseOpacity: .random(in: 0.35...1.00),
                    speed: .random(in: 0.5...2.8),
                    phase: .random(in: 0...(Double.pi * 2)),
                    colorIdx: Int.random(in: 0...3)
                )
            }
        }
    }
}

// MARK: - Midnight Static Stars

private struct StaticStarField: View {
    struct StarData { let x, y, opacity: Double; let radius: CGFloat }

    @State private var stars: [StarData] = []

    var body: some View {
        Canvas { ctx, size in
            for s in stars {
                let pos = CGPoint(x: s.x * size.width, y: s.y * size.height)
                ctx.opacity = s.opacity
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pos.x - s.radius, y: pos.y - s.radius,
                                           width: s.radius * 2, height: s.radius * 2)),
                    with: .color(.white)
                )
            }
        }
        .onAppear {
            guard stars.isEmpty else { return }
            stars = (0..<80).map { _ in
                StarData(x: .random(in: 0...1), y: .random(in: 0...1),
                         opacity: .random(in: 0.15...0.55),
                         radius: .random(in: 0.4...1.5))
            }
        }
    }
}

// MARK: - Aurora Waves

private struct AuroraWaves: View {
    private let bands: [(yRatio: Double, color: Color, amp: Double, freq: Double, speed: Double, alpha: Double)] = [
        (0.28, Color(red: 0.10, green: 0.90, blue: 0.78), 0.055, 1.6, 0.22, 0.12),
        (0.42, Color(red: 0.50, green: 0.18, blue: 0.88), 0.040, 2.1, 0.16, 0.09),
        (0.18, Color(red: 0.08, green: 0.72, blue: 0.62), 0.030, 1.3, 0.28, 0.08),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for b in bands {
                    let baseY = b.yRatio * size.height
                    let amp   = b.amp * size.height
                    let steps = max(Int(size.width / 3), 2)
                    var path = Path()
                    for i in 0...steps {
                        let xf = Double(i) / Double(steps)
                        let y = baseY + amp * sin(b.freq * .pi * 2 * xf + t * b.speed)
                        let pt = CGPoint(x: xf * size.width, y: y)
                        i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()
                    ctx.opacity = b.alpha
                    ctx.fill(path, with: .color(b.color))
                }
            }
        }
    }
}

// MARK: - Generic Drifting Particles

private enum ParticleType {
    case petals, sparks, leaves, bubbles, hearts

    var count: Int {
        switch self {
        case .petals:  return 18
        case .sparks:  return 22
        case .leaves:  return 14
        case .bubbles: return 18
        case .hearts:  return 14
        }
    }

    var color: Color {
        switch self {
        case .petals:  return Color(red: 1.00, green: 0.76, blue: 0.83)
        case .sparks:  return Color(red: 1.00, green: 0.58, blue: 0.10)
        case .leaves:  return Color(red: 0.28, green: 0.72, blue: 0.18)
        case .bubbles: return Color(red: 0.45, green: 0.88, blue: 0.95)
        case .hearts:  return Color(red: 1.00, green: 0.68, blue: 0.82)
        }
    }

    var risesUp: Bool { self == .sparks || self == .bubbles }
    var baseOpacity: Double { 0.48 }
}

private struct DriftParticles: View {
    let type: ParticleType

    struct PData {
        let startX, startY, speed, sway, swayFreq, phase, rotSpeed: Double
        let size: CGFloat
    }

    @State private var particles: [PData] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let prog = fmod((p.phase / (Double.pi * 2)) + t * p.speed, 1.0)
                    let rawY = type.risesUp ? (1.0 - prog) : prog
                    let y    = rawY * size.height
                    let x    = p.startX * size.width + sin(t * p.swayFreq + p.phase) * p.sway
                    let fade = sin(prog * .pi)
                    let opacity = type.baseOpacity * max(0, fade)

                    ctx.drawLayer { c in
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(t * p.rotSpeed * 50))
                        c.opacity = opacity
                        c.fill(
                            Path(ellipseIn: CGRect(x: -p.size/2, y: -p.size/2,
                                                   width: p.size, height: p.size)),
                            with: .color(type.color)
                        )
                    }
                }
            }
        }
        .onAppear {
            guard particles.isEmpty else { return }
            particles = (0..<type.count).map { _ in
                PData(
                    startX:   .random(in: 0...1),
                    startY:   .random(in: 0...1),
                    speed:    .random(in: 0.022...0.055),
                    sway:     .random(in: 12...38),
                    swayFreq: .random(in: 0.28...0.90),
                    phase:    .random(in: 0...(Double.pi * 2)),
                    rotSpeed: .random(in: -1.6...1.6),
                    size:     .random(in: 5...13)
                )
            }
        }
    }
}

// MARK: - Cyberpunk Grid

private struct CyberpunkGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 38
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            ctx.opacity = 0.07
            ctx.stroke(path, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)), lineWidth: 0.5)
        }
    }
}

// MARK: - Retrowave Scanlines

private struct RetrowaveScanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var y: CGFloat = 0
            while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 5 }
            ctx.opacity = 0.045
            ctx.stroke(path, with: .color(.white), lineWidth: 1)
        }
    }
}
