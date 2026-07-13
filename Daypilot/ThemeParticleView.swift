import SwiftUI

// MARK: - Dispatcher

struct ThemeParticleView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        switch selectedTheme {
        case "galaxy":    StarField(seed: 888, count: 210, maxR: 2.8, maxAlpha: 0.88)
        case "midnight":  StarField(seed: 777, count: 90,  maxR: 1.8, maxAlpha: 0.65)
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

// MARK: - View Extension (convenience)

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

// MARK: - Shared PRNG

private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func lerp(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
}

// MARK: - Star Field (Galaxy + Midnight)

private struct StarField: View {
    struct Star { let x, y, alpha: Double; let r: CGFloat }

    let stars: [Star]

    init(seed: UInt64, count: Int, maxR: CGFloat, maxAlpha: Double) {
        var rng = LCG(state: seed)
        stars = (0..<count).map { _ in
            Star(x:     rng.next(),
                 y:     rng.next(),
                 alpha: rng.lerp(0.25, Double(maxAlpha)),
                 r:     CGFloat(rng.lerp(0.5, Double(maxR))))
        }
    }

    var body: some View {
        Canvas { ctx, size in
            for s in stars {
                let px = s.x * size.width
                let py = s.y * size.height
                ctx.opacity = s.alpha
                ctx.fill(
                    Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                           width: s.r * 2, height: s.r * 2)),
                    with: .color(.white)
                )
                if s.r > 1.8 {
                    let g = s.r * 3.5
                    ctx.opacity = s.alpha * 0.22
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - g, y: py - g,
                                               width: g * 2, height: g * 2)),
                        with: .color(.white)
                    )
                }
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
                    let amp   = b.amp * size.height
                    let steps = max(Int(size.width / 3), 2)
                    var path  = Path()
                    for i in 0...steps {
                        let xf = Double(i) / Double(steps)
                        let y  = baseY + amp * sin(b.freq * .pi * 2 * xf + t * b.speed)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Shape Paths

private func petalPath(_ s: CGFloat) -> Path {
    // Asymmetric curved petal — wide on one side, rounder on the other
    Path { p in
        let w = s * 0.44, h = s * 0.60
        p.move(to: CGPoint(x: 0, y: h))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x:  w * 1.15, y:  h * 0.45),
                   control2: CGPoint(x:  w * 1.15, y: -h * 0.45))
        p.addCurve(to: CGPoint(x: 0, y: h),
                   control1: CGPoint(x: -w * 0.60, y: -h * 0.45),
                   control2: CGPoint(x: -w * 0.60, y:  h * 0.45))
    }
}

private func leafPath(_ s: CGFloat) -> Path {
    // Symmetric pointed leaf — narrow, tapers to a point both ends
    Path { p in
        let w = s * 0.28, h = s * 0.62
        p.move(to: CGPoint(x: 0, y: -h))
        p.addCurve(to: CGPoint(x: 0, y: h),
                   control1: CGPoint(x:  w, y: -h * 0.3),
                   control2: CGPoint(x:  w,  y:  h * 0.3))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x: -w,  y:  h * 0.3),
                   control2: CGPoint(x: -w,  y: -h * 0.3))
    }
}

private func heartPath(_ s: CGFloat) -> Path {
    // Classic heart using two arcs + bezier curves
    let r = s * 0.40
    return Path { p in
        p.move(to: CGPoint(x: 0, y: s * 0.52))
        p.addCurve(to: CGPoint(x: -r * 2, y: -r * 0.28),
                   control1: CGPoint(x: -r * 0.22, y: s * 0.32),
                   control2: CGPoint(x: -r * 2.00, y: r * 0.38))
        p.addArc(center: CGPoint(x: -r, y: -r * 0.80),
                 radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0),
                 clockwise: false)
        p.addArc(center: CGPoint(x:  r, y: -r * 0.80),
                 radius: r,
                 startAngle: .degrees(180), endAngle: .degrees(0),
                 clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: s * 0.52),
                   control1: CGPoint(x:  r * 2.00, y: r * 0.38),
                   control2: CGPoint(x:  r * 0.22, y: s * 0.32))
    }
}

private func sparkPath(_ s: CGFloat) -> Path {
    // Thin upward comet / ember streak
    Path { p in
        let w = s * 0.14, h = s * 0.62
        p.move(to: CGPoint(x: 0, y: -h))           // bright tip at top
        p.addCurve(to: CGPoint(x: 0, y: h * 0.38),
                   control1: CGPoint(x:  w, y: -h * 0.2),
                   control2: CGPoint(x:  w,  y:  h * 0.1))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x: -w,  y:  h * 0.1),
                   control2: CGPoint(x: -w,  y: -h * 0.2))
    }
}

// MARK: - Particle Config

private enum PConfig {
    case petals, sparks, leaves, bubbles, hearts

    var count: Int {
        switch self {
        case .petals:  return 20
        case .sparks:  return 26
        case .leaves:  return 18
        case .bubbles: return 18
        case .hearts:  return 16
        }
    }
    var color: Color {
        switch self {
        case .petals:  return Color(red: 1.00, green: 0.74, blue: 0.84)
        case .sparks:  return Color(red: 1.00, green: 0.60, blue: 0.08)
        case .leaves:  return Color(red: 0.28, green: 0.76, blue: 0.22)
        case .bubbles: return Color(red: 0.48, green: 0.88, blue: 0.96)
        case .hearts:  return Color(red: 1.00, green: 0.62, blue: 0.78)
        }
    }
    var sizeRange: (lo: Double, hi: Double) {
        switch self {
        case .petals:  return (10, 24)
        case .sparks:  return (7,  16)
        case .leaves:  return (10, 22)
        case .bubbles: return (14, 32)
        case .hearts:  return (9,  20)
        }
    }
    var risesUp: Bool  { self == .sparks || self == .bubbles }
    var rotates: Bool  { self != .bubbles }
    var baseAlpha: Double { 0.72 }
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

// MARK: - Falling / Rising Particles

private struct FallingParticles: View {

    struct P {
        let startX, speed, sway, swayHz, phase, rotHz: Double
        let size: CGFloat
    }

    let cfg: PConfig
    private let parts: [P]

    init(cfg: PConfig) {
        self.cfg = cfg
        var rng = LCG(state: cfg.seed)
        let sr = cfg.sizeRange
        parts = (0..<cfg.count).map { _ in
            P(startX: rng.next(),
              speed:   rng.lerp(0.022, 0.052),
              sway:    rng.lerp(12, 42),
              swayHz:  rng.lerp(0.22, 0.88),
              phase:   rng.lerp(0, .pi * 2),
              rotHz:   cfg.rotates ? rng.lerp(-1.6, 1.6) : 0,
              size:    CGFloat(rng.lerp(sr.lo, sr.hi)))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let col = cfg.color

                for p in parts {
                    let prog = fmod((p.phase / (.pi * 2)) + t * p.speed, 1.0)
                    let rawY = cfg.risesUp ? (1.0 - prog) : prog
                    let y    = rawY * size.height
                    let x    = p.startX * size.width + sin(t * p.swayHz + p.phase) * p.sway
                    let fade = sin(max(0, prog) * .pi)
                    let alpha = cfg.baseAlpha * fade

                    switch cfg {

                    case .petals:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 40))
                            c.opacity = alpha
                            c.fill(petalPath(p.size), with: .color(col))
                            // slightly lighter inner highlight
                            c.opacity = alpha * 0.50
                            c.fill(petalPath(p.size * 0.55),
                                   with: .color(Color(red: 1, green: 0.92, blue: 0.96)))
                        }

                    case .leaves:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 40))
                            c.opacity = alpha
                            c.fill(leafPath(p.size), with: .color(col))
                            // vein
                            c.opacity = alpha * 0.55
                            var vein = Path()
                            vein.move(to: CGPoint(x: 0, y: -p.size * 0.58))
                            vein.addLine(to: CGPoint(x: 0,  y:  p.size * 0.58))
                            c.stroke(vein,
                                     with: .color(Color(red: 0.15, green: 0.55, blue: 0.10)),
                                     lineWidth: 0.8)
                        }

                    case .hearts:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 30))
                            c.opacity = alpha
                            c.fill(heartPath(p.size), with: .color(col))
                        }

                    case .sparks:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 50))
                            // glow halo behind spark
                            let gr = p.size * 0.45
                            c.opacity = alpha * 0.32
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr,
                                                       width: gr * 2, height: gr * 2)),
                                with: .color(Color(red: 1, green: 0.88, blue: 0.30))
                            )
                            c.opacity = alpha
                            c.fill(sparkPath(p.size), with: .color(col))
                            // bright core tip
                            c.opacity = alpha * 0.85
                            c.fill(
                                Path(ellipseIn: CGRect(x: -p.size*0.12,
                                                       y: -p.size*0.58,
                                                       width: p.size*0.24,
                                                       height: p.size*0.24)),
                                with: .color(.white)
                            )
                        }

                    case .bubbles:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            let r = p.size / 2
                            let circ = Path(ellipseIn: CGRect(x: -r, y: -r,
                                                              width: r * 2, height: r * 2))
                            // body fill (very faint)
                            c.opacity = alpha * 0.18
                            c.fill(circ, with: .color(col))
                            // main rim
                            c.opacity = alpha * 0.80
                            c.stroke(circ, with: .color(col), lineWidth: 1.6)
                            // specular highlight
                            c.opacity = alpha * 0.90
                            c.fill(
                                Path(ellipseIn: CGRect(x: -r * 0.55, y: -r * 0.65,
                                                       width: r * 0.40, height: r * 0.26)),
                                with: .color(.white)
                            )
                        }
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
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += 5
            }
            ctx.opacity = 0.08
            ctx.stroke(path, with: .color(.white), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
