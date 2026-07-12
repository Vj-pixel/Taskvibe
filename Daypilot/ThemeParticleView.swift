import SwiftUI

// MARK: - Dispatcher

struct ThemeParticleView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        switch selectedTheme {
        case "galaxy":    GalaxyStarField()
        case "midnight":  StaticStarField()
        case "aurora":    AuroraWaves()
        case "sakura":    FallingParticles(cfg: .petals)
        case "ember":     FallingParticles(cfg: .sparks)
        case "forest":    FallingParticles(cfg: .leaves)
        case "ocean":     FallingParticles(cfg: .bubbles)
        case "cyberpunk": GridOverlay()
        case "retrowave": ScanlineOverlay()
        case "cute":      FallingParticles(cfg: .hearts)
        default:          EmptyView()
        }
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

// MARK: - Galaxy Starfield

private struct GalaxyStarField: View {

    struct Star {
        let x, y: Double
        let r: CGFloat
        let base: Double   // base opacity 0…1
        let hz: Double     // twinkle freq
        let phase: Double  // twinkle phase
        let col: Int
    }

    // static so the positions never change between re-renders
    static let stars: [Star] = {
        let palette = [0, 0, 0, 1, 1, 2, 3]   // bias towards white
        return (0..<260).map { _ in
            Star(
                x:     .random(in: 0...1),
                y:     .random(in: 0...1),
                r:     .random(in: 0.8...3.6),
                base:  .random(in: 0.55...1.00),
                hz:    .random(in: 0.3...2.2),
                phase: .random(in: 0 ..< .pi * 2),
                col:   palette.randomElement()!
            )
        }
    }()

    private let palette: [Color] = [
        .white,
        Color(red: 0.88, green: 0.93, blue: 1.00),
        Color(red: 0.76, green: 0.84, blue: 1.00),
        Color(red: 0.98, green: 0.92, blue: 1.00)
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in Self.stars {
                    let flicker = sin(t * s.hz + s.phase) * 0.5 + 0.5   // 0…1
                    let alpha   = s.base * (0.40 + 0.60 * flicker)
                    let px = s.x * size.width
                    let py = s.y * size.height
                    let color = palette[s.col]

                    // core dot
                    ctx.opacity = alpha
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                               width: s.r * 2, height: s.r * 2)),
                        with: .color(color)
                    )
                    // soft glow for larger stars
                    if s.r > 1.8 {
                        let gr = s.r * 4
                        ctx.opacity = alpha * 0.25
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - gr, y: py - gr,
                                                   width: gr * 2, height: gr * 2)),
                            with: .color(color)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Midnight Static Stars

private struct StaticStarField: View {

    struct Star { let x, y, alpha: Double; let r: CGFloat }

    static let stars: [Star] = (0..<90).map { _ in
        Star(x:     .random(in: 0...1),
             y:     .random(in: 0...1),
             alpha: .random(in: 0.30...0.70),
             r:     .random(in: 0.6...1.8))
    }

    var body: some View {
        Canvas { ctx, size in
            for s in Self.stars {
                ctx.opacity = s.alpha
                ctx.fill(
                    Path(ellipseIn: CGRect(x: s.x * size.width - s.r,
                                           y: s.y * size.height - s.r,
                                           width: s.r * 2, height: s.r * 2)),
                    with: .color(.white)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Aurora Waves

private struct AuroraWaves: View {

    private struct Band {
        let yRatio, amp, freq, speed, alpha: Double
        let color: Color
    }

    private let bands: [Band] = [
        Band(yRatio: 0.25, amp: 0.07, freq: 1.5, speed: 0.20, alpha: 0.22,
             color: Color(red: 0.08, green: 0.92, blue: 0.80)),
        Band(yRatio: 0.40, amp: 0.05, freq: 2.0, speed: 0.14, alpha: 0.16,
             color: Color(red: 0.48, green: 0.18, blue: 0.90)),
        Band(yRatio: 0.16, amp: 0.04, freq: 1.2, speed: 0.26, alpha: 0.14,
             color: Color(red: 0.06, green: 0.75, blue: 0.62)),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for b in bands {
                    let baseY = b.yRatio * size.height
                    let amp   = b.amp   * size.height
                    let steps = max(Int(size.width / 3), 2)
                    var path  = Path()
                    for i in 0...steps {
                        let xf = Double(i) / Double(steps)
                        let y  = baseY + amp * sin(b.freq * .pi * 2 * xf + t * b.speed)
                        let pt = CGPoint(x: xf * size.width, y: y)
                        i == 0 ? path.move(to: pt) : path.addLine(to: pt)
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0,          y: size.height))
                    path.closeSubpath()
                    ctx.opacity = b.alpha
                    ctx.fill(path, with: .color(b.color))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Generic Drifting Particles

private enum PConfig {
    case petals, sparks, leaves, bubbles, hearts

    var count: Int {
        switch self {
        case .petals:  return 22
        case .sparks:  return 28
        case .leaves:  return 18
        case .bubbles: return 22
        case .hearts:  return 18
        }
    }
    var color: Color {
        switch self {
        case .petals:  Color(red: 1.00, green: 0.75, blue: 0.82)
        case .sparks:  Color(red: 1.00, green: 0.62, blue: 0.10)
        case .leaves:  Color(red: 0.30, green: 0.75, blue: 0.20)
        case .bubbles: Color(red: 0.50, green: 0.88, blue: 0.95)
        case .hearts:  Color(red: 1.00, green: 0.65, blue: 0.80)
        }
    }
    var risesUp: Bool { self == .sparks || self == .bubbles }
    var baseAlpha: Double { 0.65 }
    var sizeRange: ClosedRange<CGFloat> { 6...16 }
    var seed: UInt64 {
        switch self {
        case .petals:  return 101
        case .sparks:  return 202
        case .leaves:  return 303
        case .bubbles: return 404
        case .hearts:  return 505
        }
    }
}

private struct FallingParticles: View {

    let cfg: PConfig

    struct P {
        let startX, speed, sway, swayHz, phase, rotHz: Double
        let size: CGFloat
    }

    // Seeded PRNG — deterministic, no onAppear needed
    private static func makeParts(_ cfg: PConfig) -> [P] {
        var s: UInt64 = cfg.seed
        func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(1 << 53)
        }
        func lerp(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
        return (0..<cfg.count).map { _ in
            P(startX: next(),
              speed:   lerp(0.025, 0.055),
              sway:    lerp(14, 40),
              swayHz:  lerp(0.25, 0.85),
              phase:   lerp(0, .pi * 2),
              rotHz:   lerp(-1.8, 1.8),
              size:    CGFloat(lerp(Double(cfg.sizeRange.lowerBound),
                                   Double(cfg.sizeRange.upperBound))))
        }
    }

    private let parts: [P]
    init(cfg: PConfig) { self.cfg = cfg; parts = Self.makeParts(cfg) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for p in parts {
                    let prog = fmod((p.phase / (.pi * 2)) + t * p.speed, 1.0)
                    let rawY = cfg.risesUp ? (1.0 - prog) : prog
                    let y    = rawY * size.height
                    let x    = p.startX * size.width + sin(t * p.swayHz + p.phase) * p.sway
                    let fade = sin(max(0, prog) * .pi)
                    ctx.drawLayer { c in
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .degrees(t * p.rotHz * 45))
                        c.opacity = cfg.baseAlpha * fade
                        c.fill(
                            Path(ellipseIn: CGRect(x: -p.size/2, y: -p.size/2,
                                                   width: p.size, height: p.size)),
                            with: .color(cfg.color)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Cyberpunk Grid

private struct GridOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 36
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            ctx.opacity = 0.13
            ctx.stroke(path, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)), lineWidth: 0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Retrowave Scanlines

private struct ScanlineOverlay: View {
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0,          y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 5
            }
            ctx.opacity = 0.08
            ctx.stroke(path, with: .color(.white), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
