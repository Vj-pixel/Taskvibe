// OnboardingView.swift

import SwiftUI

// MARK: - Onboarding Flow

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var phase: OnboardingPhase = .splash

    enum OnboardingPhase {
        case splash, pages
    }

    var body: some View {
        ZStack {
            if phase == .splash {
                SplashScreen()
                    .transition(.opacity)
            } else {
                IntroPageFlow(onFinished: onFinished)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: phase)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { phase = .pages }
            }
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: CGFloat = 0.0
    @State private var taglineOpacity: CGFloat = 0.0

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 140, height: 140)
                    Circle()
                        .fill(Color.blue.opacity(0.09))
                        .frame(width: 180, height: 180)
                    Image(systemName: "metronome.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Momentum")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Keep your momentum.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                }
                .opacity(taglineOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.7)) {
                taglineOpacity = 1.0
            }
        }
    }
}

// MARK: - Intro Page Flow

private struct IntroPage {
    let systemImage: String
    let imageColor: Color
    let title: String
    let subtitle: String
}

struct IntroPageFlow: View {
    var onFinished: () -> Void

    private let pages: [IntroPage] = [
        IntroPage(
            systemImage: "metronome.fill",
            imageColor: .blue,
            title: "Build Your Momentum",
            subtitle: "Start small, think big. Add tasks and habits that keep you moving forward — every single day."
        ),
        IntroPage(
            systemImage: "flame.fill",
            imageColor: .orange,
            title: "Track Every Swing",
            subtitle: "Your habits build streaks. Each completion swings you closer to your goals and earns you a higher rank."
        ),
        IntroPage(
            systemImage: "calendar.badge.clock",
            imageColor: .green,
            title: "Never Lose Pace",
            subtitle: "The built-in calendar keeps deadlines in sight so your momentum never stalls."
        ),
        IntroPage(
            systemImage: "arrow.right.circle.fill",
            imageColor: .yellow,
            title: "Let's Set Things in Motion",
            subtitle: "Create an account to start building unstoppable momentum. Your best run starts now."
        )
    ]

    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentPage = pages.count - 1
                            }
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white.opacity(0.55))
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

                // Dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.28))
                            .frame(
                                width: currentPage == index ? 26 : 8,
                                height: 8
                            )
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 28)

                // CTA
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage += 1
                        }
                    } else {
                        onFinished()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            .font(.headline)
                        if currentPage == pages.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                currentPage == pages.count - 1
                                    ? Color.blue
                                    : Color.blue.opacity(0.75)
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
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

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.imageColor.opacity(0.12))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(page.imageColor.opacity(0.07))
                    .frame(width: 270, height: 270)
                Image(systemName: page.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .foregroundStyle(page.imageColor)
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 28)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - Shared Background

private var backgroundGradient: some View {
    LinearGradient(
        gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
}

#Preview("Onboarding") {
    OnboardingView(onFinished: {})
}
