import SwiftUI

// MARK: - Dispatcher

struct ThemeParticleView: View {
    @AppStorage("selectedTheme") private var selectedTheme = "original"

    var body: some View {
        switch selectedTheme {
        case "galaxy":    GalaxyView()
        case "midnight":  TwinklingStars()
        case "aurora":    AuroraWaves()
        case "sakura":    FallingParticles(cfg: .petals)
        case "ember":     FallingParticles(cfg: .sparks)
        case "forest":    FallingParticles(cfg: .leaves)
        case "ocean":     FallingParticles(cfg: .bubbles)
        case "cyberpunk": CyberpunkGrid()
        case "retrowave": RetrowaveScanlines()
        case "cute":      FallingParticles(cfg: .hearts)
        case "tangerine": FallingParticles(cfg: .sparkles)
        case "dusk":      FallingParticles(cfg: .motes)
        case "slate":     FallingParticles(cfg: .dust)
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

// MARK: - Shared PRNG

private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func lerp(_ lo: Double, _ hi: Double) -> Double { lo + next() * (hi - lo) }
}

// MARK: - Galaxy (animated spiral)

private struct GalaxyView: View {

    struct ArmStar {
        let baseAngle: Double   // angle relative to rotation origin
        let r: Double           // 0..1 normalized radius
        let dotAlpha: Double
        let dotR: CGFloat
        let dustAlpha: Double
        let dustR: CGFloat
        let dustColor: Color
    }
    struct BgStar { let x, y: Double; let alpha: Double; let r: CGFloat }

    private let armStars: [ArmStar]
    private let bgStars:  [BgStar]

    init() {
        var rng  = LCG(state: 9901)
        let perArm = 85
        let nebColors: [Color] = [
            Color(red: 0.55, green: 0.32, blue: 0.95),
            Color(red: 0.40, green: 0.58, blue: 1.00),
            Color(red: 0.80, green: 0.62, blue: 1.00),
            Color(red: 0.30, green: 0.20, blue: 0.88),
        ]
        var stars: [ArmStar] = []
        for arm in [0.0, Double.pi] {
            for i in 0..<perArm {
                let t       = Double(i) / Double(perArm)
                let theta   = t * .pi * 3.0
                let scatter = rng.lerp(-0.14, 0.14)
                let rScatt  = rng.lerp(-0.05, 0.05)
                let r       = max(0.05, t * 0.93 + rScatt)
                let inner   = t < 0.18
                let ci      = Int(rng.next() * Double(nebColors.count))
                stars.append(ArmStar(
                    baseAngle: arm + theta + scatter,
                    r:         r,
                    dotAlpha:  rng.lerp(0.50, 0.92),
                    dotR:      CGFloat(rng.lerp(0.5, inner ? 2.2 : 1.5)),
                    dustAlpha: t < 0.85 ? rng.lerp(0.04, 0.10) : 0,
                    dustR:     CGFloat(rng.lerp(6, inner ? 20 : 12)),
                    dustColor: nebColors[ci % nebColors.count]
                ))
            }
        }
        armStars = stars
        bgStars  = (0..<70).map { _ in
            BgStar(x: rng.next(), y: rng.next(),
                   alpha: rng.lerp(0.12, 0.50),
                   r: CGFloat(rng.lerp(0.4, 1.4)))
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let t   = tl.date.timeIntervalSinceReferenceDate
                let rot = t * 0.016          // one full turn ≈ 393 s
                let cx  = size.width  * 0.50
                let cy  = size.height * 0.47
                let sc  = min(size.width, size.height) * 0.38
                let ax: CGFloat = 1.00       // horizontal scale
                let ay: CGFloat = 0.40       // vertical compression — oblique view

                // Background stars
                for s in bgStars {
                    ctx.opacity = s.alpha
                    let px = CGFloat(s.x) * size.width
                    let py = CGFloat(s.y) * size.height
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                               width: s.r * 2, height: s.r * 2)),
                        with: .color(.white))
                }

                // Faint outer galactic disk
                let dk = sc * 1.12
                ctx.opacity = 0.07
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - dk * ax, y: cy - dk * ay,
                                           width: dk * 2 * ax, height: dk * 2 * ay)),
                    with: .color(Color(red: 0.50, green: 0.35, blue: 0.90)))

                // Arm nebula dust (behind stars)
                for s in armStars where s.dustAlpha > 0 {
                    let ang = s.baseAngle + rot
                    let rx  = CGFloat(s.r) * sc
                    let px  = cx + rx * CGFloat(cos(ang)) * ax
                    let py  = cy + rx * CGFloat(sin(ang)) * ay
                    let dr  = s.dustR
                    ctx.opacity = s.dustAlpha
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - dr, y: py - dr,
                                               width: dr * 2, height: dr * 2)),
                        with: .color(s.dustColor))
                }

                // Core glow (outermost → innermost)
                let coreLayers: [(CGFloat, Double, Color)] = [
                    (sc * 0.38, 0.07, Color(red: 0.50, green: 0.32, blue: 0.92)),
                    (sc * 0.22, 0.14, Color(red: 0.68, green: 0.50, blue: 1.00)),
                    (sc * 0.10, 0.30, Color(red: 0.85, green: 0.75, blue: 1.00)),
                    (sc * 0.04, 0.70, Color.white),
                ]
                for (cr, al, col) in coreLayers {
                    ctx.opacity = al
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - cr * ax, y: cy - cr * ay,
                                               width: cr * 2 * ax, height: cr * 2 * ay)),
                        with: .color(col))
                }

                // Arm star dots (on top of dust)
                for s in armStars {
                    let ang = s.baseAngle + rot
                    let rx  = CGFloat(s.r) * sc
                    let px  = cx + rx * CGFloat(cos(ang)) * ax
                    let py  = cy + rx * CGFloat(sin(ang)) * ay
                    ctx.opacity = s.dotAlpha
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - s.dotR, y: py - s.dotR,
                                               width: s.dotR * 2, height: s.dotR * 2)),
                        with: .color(.white))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Twinkling Stars (Midnight)

private struct TwinklingStars: View {
    struct TStar {
        let x, y: Double
        let baseAlpha, amp, hz, phase: Double
        let r: CGFloat
    }
    private static let stars: [TStar] = {
        var rng = LCG(state: 777)
        return (0..<90).map { _ in
            let r = CGFloat(rng.lerp(0.5, 1.8))
            return TStar(x: rng.next(), y: rng.next(),
                         baseAlpha: rng.lerp(0.28, 0.65),
                         amp:   rng.lerp(0.06, 0.22),
                         hz:    rng.lerp(0.3, 1.8),
                         phase: rng.lerp(0, .pi * 2),
                         r: r)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for s in Self.stars {
                    let alpha = max(0, s.baseAlpha + s.amp * sin(t * s.hz + s.phase))
                    let px = CGFloat(s.x) * size.width
                    let py = CGFloat(s.y) * size.height
                    ctx.opacity = alpha
                    ctx.fill(Path(ellipseIn: CGRect(x: px - s.r, y: py - s.r,
                                                    width: s.r * 2, height: s.r * 2)),
                             with: .color(.white))
                    if s.r > 1.3 {
                        let g = s.r * 3.2
                        ctx.opacity = alpha * 0.18
                        ctx.fill(Path(ellipseIn: CGRect(x: px - g, y: py - g,
                                                        width: g * 2, height: g * 2)),
                                 with: .color(.white))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    let r = s * 0.40
    return Path { p in
        p.move(to: CGPoint(x: 0, y: s * 0.52))
        p.addCurve(to: CGPoint(x: -r * 2, y: -r * 0.28),
                   control1: CGPoint(x: -r * 0.22, y: s * 0.32),
                   control2: CGPoint(x: -r * 2.00, y: r * 0.38))
        p.addArc(center: CGPoint(x: -r, y: -r * 0.80),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x:  r, y: -r * 0.80),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: s * 0.52),
                   control1: CGPoint(x:  r * 2.00, y: r * 0.38),
                   control2: CGPoint(x:  r * 0.22, y: s * 0.32))
    }
}

private func sparkPath(_ s: CGFloat) -> Path {
    Path { p in
        let w = s * 0.14, h = s * 0.62
        p.move(to: CGPoint(x: 0, y: -h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.38),
                   control1: CGPoint(x:  w, y: -h * 0.2),
                   control2: CGPoint(x:  w,  y:  h * 0.1))
        p.addCurve(to: CGPoint(x: 0, y: -h),
                   control1: CGPoint(x: -w,  y:  h * 0.1),
                   control2: CGPoint(x: -w,  y: -h * 0.2))
    }
}

private func sparklePath(_ s: CGFloat) -> Path {
    // 4-pointed star
    Path { p in
        let r1 = s * 0.50, r2 = s * 0.14
        for i in 0..<8 {
            let a  = Double(i) * .pi / 4
            let r  = i % 2 == 0 ? r1 : r2
            let pt = CGPoint(x: CGFloat(cos(a)) * r, y: CGFloat(sin(a)) * r)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
    }
}

// MARK: - Particle Config

private enum PConfig {
    case petals, sparks, leaves, bubbles, hearts
    case sparkles, motes, dust

    var count: Int {
        switch self {
        case .petals:   return 20
        case .sparks:   return 26
        case .leaves:   return 18
        case .bubbles:  return 18
        case .hearts:   return 16
        case .sparkles: return 22
        case .motes:    return 20
        case .dust:     return 28
        }
    }
    var color: Color {
        switch self {
        case .petals:   return Color(red: 1.00, green: 0.74, blue: 0.84)
        case .sparks:   return Color(red: 1.00, green: 0.60, blue: 0.08)
        case .leaves:   return Color(red: 0.28, green: 0.76, blue: 0.22)
        case .bubbles:  return Color(red: 0.48, green: 0.88, blue: 0.96)
        case .hearts:   return Color(red: 1.00, green: 0.62, blue: 0.78)
        case .sparkles: return Color(red: 1.00, green: 0.72, blue: 0.12)
        case .motes:    return Color(red: 1.00, green: 0.62, blue: 0.38)
        case .dust:     return Color(red: 0.72, green: 0.82, blue: 0.95)
        }
    }
    var sizeRange: (lo: Double, hi: Double) {
        switch self {
        case .petals:   return (10, 24)
        case .sparks:   return (7,  16)
        case .leaves:   return (10, 22)
        case .bubbles:  return (14, 32)
        case .hearts:   return (9,  20)
        case .sparkles: return (4,  10)
        case .motes:    return (3,   8)
        case .dust:     return (2,   6)
        }
    }
    var risesUp: Bool {
        switch self {
        case .sparks, .bubbles, .motes, .dust: return true
        default: return false
        }
    }
    var rotates: Bool {
        switch self {
        case .bubbles, .motes, .dust: return false
        default: return true
        }
    }
    var baseAlpha: Double {
        switch self {
        case .dust:  return 0.45
        case .motes: return 0.55
        default:     return 0.72
        }
    }
    var seed: UInt64 {
        switch self {
        case .petals:   return 101
        case .sparks:   return 202
        case .leaves:   return 303
        case .bubbles:  return 404
        case .hearts:   return 505
        case .sparkles: return 606
        case .motes:    return 707
        case .dust:     return 808
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
        var rng  = LCG(state: cfg.seed)
        let sr   = cfg.sizeRange
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
                let t   = tl.date.timeIntervalSinceReferenceDate
                let col = cfg.color

                // Hearts: pick contrasting color based on hour so they're always visible
                let hour = Calendar.current.component(.hour, from: tl.date)
                let heartFill: Color = (hour >= 6 && hour < 19)
                    ? Color(red: 0.85, green: 0.10, blue: 0.52)   // deep raspberry for light day bg
                    : Color(red: 1.00, green: 0.80, blue: 0.92)   // pale pink for dark night bg

                for p in parts {
                    let prog  = fmod((p.phase / (.pi * 2)) + t * p.speed, 1.0)
                    let rawY  = cfg.risesUp ? (1.0 - prog) : prog
                    let y     = rawY * size.height
                    let x     = p.startX * size.width + sin(t * p.swayHz + p.phase) * p.sway
                    let fade  = sin(max(0, prog) * .pi)
                    let alpha = cfg.baseAlpha * fade

                    switch cfg {

                    case .petals:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 40))
                            c.opacity = alpha
                            c.fill(petalPath(p.size), with: .color(col))
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
                            c.fill(heartPath(p.size), with: .color(heartFill))
                            c.opacity = alpha * 0.40
                            c.stroke(heartPath(p.size), with: .color(.white), lineWidth: 1.0)
                        }

                    case .sparks:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 50))
                            let gr = p.size * 0.45
                            c.opacity = alpha * 0.32
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(Color(red: 1, green: 0.88, blue: 0.30)))
                            c.opacity = alpha
                            c.fill(sparkPath(p.size), with: .color(col))
                            c.opacity = alpha * 0.85
                            c.fill(
                                Path(ellipseIn: CGRect(x: -p.size*0.12, y: -p.size*0.58,
                                                       width: p.size*0.24, height: p.size*0.24)),
                                with: .color(.white))
                        }

                    case .bubbles:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            let r    = p.size / 2
                            let circ = Path(ellipseIn: CGRect(x: -r, y: -r, width: r*2, height: r*2))
                            c.opacity = alpha * 0.18
                            c.fill(circ, with: .color(col))
                            c.opacity = alpha * 0.80
                            c.stroke(circ, with: .color(col), lineWidth: 1.6)
                            c.opacity = alpha * 0.90
                            c.fill(
                                Path(ellipseIn: CGRect(x: -r*0.55, y: -r*0.65,
                                                       width: r*0.40, height: r*0.26)),
                                with: .color(.white))
                        }

                    case .sparkles:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            c.rotate(by: .degrees(t * p.rotHz * 55))
                            let gr = p.size * 0.50
                            c.opacity = alpha * 0.25
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(col))
                            c.opacity = alpha
                            c.fill(sparklePath(p.size), with: .color(col))
                            c.opacity = alpha * 0.75
                            c.fill(sparklePath(p.size * 0.48), with: .color(.white))
                        }

                    case .motes, .dust:
                        ctx.drawLayer { c in
                            c.translateBy(x: x, y: y)
                            let r  = p.size / 2
                            let gr = r * 3.0
                            c.opacity = alpha * 0.25
                            c.fill(
                                Path(ellipseIn: CGRect(x: -gr, y: -gr, width: gr*2, height: gr*2)),
                                with: .color(col))
                            c.opacity = alpha
                            c.fill(
                                Path(ellipseIn: CGRect(x: -r, y: -r, width: r*2, height: r*2)),
                                with: .color(col))
                            let cr = r * 0.45
                            c.opacity = alpha * 0.75
                            c.fill(
                                Path(ellipseIn: CGRect(x: -cr, y: -cr, width: cr*2, height: cr*2)),
                                with: .color(.white))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Cyberpunk Grid (with animated scan bar)

private struct CyberpunkGrid: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            Canvas { ctx, size in
                let t    = tl.date.timeIntervalSinceReferenceDate
                let step: CGFloat = 36
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width {
                    grid.move(to: CGPoint(x: gx, y: 0))
                    grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += step
                }
                var gy: CGFloat = 0
                while gy <= size.height {
                    grid.move(to: CGPoint(x: 0, y: gy))
                    grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += step
                }
                ctx.opacity = 0.13
                ctx.stroke(grid,
                           with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)),
                           lineWidth: 0.6)

                // Horizontal scan bar sweeping down
                let scanY = CGFloat(fmod(t * 0.22, 1.0)) * size.height
                var bar   = Path()
                bar.addRect(CGRect(x: 0, y: scanY, width: size.width, height: 3))
                ctx.opacity = 0.30
                ctx.fill(bar, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)))
                // Glow trail above bar
                var glow = Path()
                glow.addRect(CGRect(x: 0, y: max(0, scanY - 18), width: size.width, height: 18))
                ctx.opacity = 0.07
                ctx.fill(glow, with: .color(Color(red: 0.00, green: 1.00, blue: 0.40)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Retrowave Scanlines (scrolling)

private struct RetrowaveScanlines: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { tl in
            Canvas { ctx, size in
                let t       = tl.date.timeIntervalSinceReferenceDate
                let spacing: CGFloat = 5
                let offset  = CGFloat(fmod(t * 10.0, Double(spacing)))
                var path    = Path()
                var y       = offset - spacing
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                ctx.opacity = 0.09
                ctx.stroke(path, with: .color(.white), lineWidth: 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
