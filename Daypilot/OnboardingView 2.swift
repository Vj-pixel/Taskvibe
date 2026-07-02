// OnboardingView.swift

import SwiftUI

// MARK: - Onboarding Flow

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var phase: OnboardingPhase = .splash

    enum OnboardingPhase { case splash, pages }

    var body: some View {
        ZStack {
            if phase == .splash {
                SplashScreen()
                    .transition(.opacity)
            } else {
                IntroPageFlow(onFinished: onFinished)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.55), value: phase)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation { phase = .pages }
            }
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowOpacity: Double = 0.18
    @State private var ringScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            onboardingBackground(.blue)
            FloatingParticles(color: .blue, count: 8)

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(glowOpacity))
                        .frame(width: 200, height: 200)
                        .scaleEffect(ringScale)
                        .animation(
                            .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                            value: ringScale
                        )
                    Circle()
                        .fill(Color.blue.opacity(0.10))
                        .frame(width: 155, height: 155)
                    Image(systemName: "metronome.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.blue.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("Daypilot")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Build momentum. Every day.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.62))
                }
                .opacity(taglineOpacity)
                .offset(y: taglineOpacity == 0 ? 10 : 0)
                .animation(.easeOut(duration: 0.5), value: taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.58).delay(0.15)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.55).delay(0.65)) {
                taglineOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 2.2).delay(0.3).repeatForever(autoreverses: true)) {
                glowOpacity = 0.32
                ringScale = 1.08
            }
        }
    }
}

// MARK: - Floating Particles Background

private struct FloatingParticles: View {
    let color: Color
    var count: Int = 7
    @State private var offsets: [CGSize] = []
    @State private var opacities: [Double] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let size = CGFloat.random(in: 8...22)
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: size, height: size)
                        .blur(radius: 2)
                        .offset(
                            x: CGFloat.random(in: -geo.size.width / 2...geo.size.width / 2),
                            y: CGFloat.random(in: -geo.size.height / 2...geo.size.height / 2)
                        )
                        .offset(i < offsets.count ? offsets[i] : .zero)
                        .opacity(i < opacities.count ? opacities[i] : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onAppear {
            offsets = (0..<count).map { _ in CGSize(width: 0, height: 0) }
            opacities = (0..<count).map { _ in Double.random(in: 0.3...0.7) }
            animateParticles()
        }
    }

    private func animateParticles() {
        for i in 0..<count {
            let delay = Double(i) * 0.25
            withAnimation(
                .easeInOut(duration: Double.random(in: 3.0...5.5))
                    .delay(delay)
                    .repeatForever(autoreverses: true)
            ) {
                offsets[i] = CGSize(
                    width: CGFloat.random(in: -40...40),
                    height: CGFloat.random(in: -40...40)
                )
            }
        }
    }
}

// MARK: - Intro Page Flow

private struct IntroPage {
    let systemImage: String
    let accentColor: Color
    let title: String
    let subtitle: String
}

struct IntroPageFlow: View {
    var onFinished: () -> Void

    private let pages: [IntroPage] = [
        IntroPage(
            systemImage: "metronome.fill",
            accentColor: .blue,
            title: "Build Your Momentum",
            subtitle: "Start small, think big. Add tasks and habits that keep you moving forward — every single day."
        ),
        IntroPage(
            systemImage: "flame.fill",
            accentColor: .orange,
            title: "Track Every Swing",
            subtitle: "Your habits build streaks. Each completion swings you closer to your goals and earns you a higher rank."
        ),
        IntroPage(
            systemImage: "calendar.badge.clock",
            accentColor: Color(red: 0.2, green: 0.8, blue: 0.45),
            title: "Never Lose Pace",
            subtitle: "The built-in calendar keeps deadlines in sight. Focus timer helps you crush each session."
        ),
        IntroPage(
            systemImage: "arrow.right.circle.fill",
            accentColor: Color(red: 0.95, green: 0.8, blue: 0.2),
            title: "Ready to Take Off?",
            subtitle: "Create an account to start building unstoppable momentum. Your best run starts now."
        )
    ]

    @State private var currentPage = 0
    @State private var showFinishConfetti = false

    var body: some View {
        ZStack {
            onboardingBackground(pages[currentPage].accentColor)
                .animation(.easeInOut(duration: 0.55), value: currentPage)

            FloatingParticles(color: pages[currentPage].accentColor, count: 7)
                .animation(.easeInOut(duration: 0.55), value: currentPage)

            if showFinishConfetti {
                ConfettiView(count: 45)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            HapticEngine.impact(.light)
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                currentPage = pages.count - 1
                            }
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .frame(height: 52)
                .padding(.top, 8)

                // Pages
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        IntroPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    HapticEngine.impact(.soft)
                }

                // Dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.28))
                            .frame(width: currentPage == index ? 28 : 8, height: 8)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 28)

                // CTA
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            currentPage += 1
                        }
                        HapticEngine.impact(.light)
                    } else {
                        HapticEngine.notification(.success)
                        showFinishConfetti = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            onFinished()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                        Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                            .font(.headline)
                    }
                    .foregroundColor(currentPage == pages.count - 1 ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(currentPage == pages.count - 1
                                  ? Color.white
                                  : pages[currentPage].accentColor.opacity(0.82))
                    )
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: currentPage)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Single Intro Page

private struct IntroPageView: View {
    let page: IntroPage

    @State private var iconScale: CGFloat = 0.3
    @State private var iconRotation: Double = -18
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 230, height: 230)
                Circle()
                    .fill(page.accentColor.opacity(0.08))
                    .frame(width: 285, height: 285)
                Image(systemName: page.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, page.accentColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .scaleEffect(iconScale)
            .rotationEffect(.degrees(iconRotation))
            .opacity(iconOpacity)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 28)
                    .opacity(subtitleOpacity)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                iconScale = 1.0
                iconRotation = 0
                iconOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.28)) {
                subtitleOpacity = 1.0
            }
        }
        .onDisappear {
            iconScale = 0.3; iconRotation = -18; iconOpacity = 0
            titleOffset = 30; titleOpacity = 0; subtitleOpacity = 0
        }
    }
}

// MARK: - Shared Background

private func onboardingBackground(_ accent: Color) -> some View {
    ZStack {
        LinearGradient(
            colors: [Color(white: 0.04), accent.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        LinearGradient(
            colors: [accent.opacity(0.18), .clear],
            startPoint: .bottomTrailing,
            endPoint: .topLeading
        )
    }
    .ignoresSafeArea()
}

#Preview("Onboarding") {
    OnboardingView(onFinished: {})
}
