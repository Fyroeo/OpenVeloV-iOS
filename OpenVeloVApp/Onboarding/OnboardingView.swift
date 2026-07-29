import CoreLocation
import SwiftUI
import UIKit

struct OnboardingView: View {
    let locationManager: LocationManager
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var step: Step = .welcome
    @State private var isRequestingPermission = false
    @State private var outcomes: [Step: Outcome] = [:]

    enum Step: Int, CaseIterable, Identifiable, Hashable {
        case welcome, location, notifications
        var id: Self { self }
    }

    enum Outcome: Equatable {
        case granted
        case declined
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            pages
                // An inset rather than an overlay, so the copy scrolls clear of the button
                // instead of ending up underneath it.
                .safeAreaInset(edge: .bottom, spacing: 0) { controls }
        }
        .background(Color(.systemBackground))
        .onChange(of: step) { _, _ in
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.secondarySystemFill), in: Circle())
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome || isRequestingPermission)
            .accessibilityLabel("Back")
            .accessibilityHidden(step == .welcome)

            OnboardingProgressBar(current: step.rawValue, total: Step.allCases.count)

            Button("Skip") { finish() }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(step == .welcome ? 0 : 1)
                .disabled(step == .welcome || isRequestingPermission)
                .accessibilityHidden(step == .welcome)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .animation(.smooth(duration: 0.25), value: step)
    }

    // MARK: - Pages

    private var pages: some View {
        TabView(selection: $step) {
            ForEach(Step.allCases) { pageStep in
                OnboardingPage(
                    content: content(for: pageStep),
                    isActive: step == pageStep,
                    illustrationHeight: illustrationHeight
                )
                .tag(pageStep)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.smooth(duration: 0.35), value: step)
    }

    private var illustrationHeight: CGFloat? {
        if dynamicTypeSize.isAccessibilitySize { return nil }
        return dynamicTypeSize >= .xxLarge ? 180 : 250
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                performPrimaryAction()
            } label: {
                ZStack {
                    // All three states are stacked and cross-faded: swapping the label in place
                    // would resize the button mid-animation.
                    primaryLabel
                        .opacity(isRequestingPermission || outcome != nil ? 0 : 1)

                    if isRequestingPermission {
                        ProgressView()
                            .tint(.white)
                    }

                    if let outcome, !isRequestingPermission {
                        Label(
                            outcome == .granted ? "Allowed" : "Maybe later",
                            systemImage: outcome == .granted ? "checkmark.circle.fill" : "arrow.right.circle.fill"
                        )
                        .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(outcome == .granted ? .green : .blue)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .disabled(isRequestingPermission)
            .animation(.smooth(duration: 0.3), value: outcome)
            .animation(.smooth(duration: 0.2), value: isRequestingPermission)

            if let secondaryTitle = content(for: step).secondaryTitle {
                Button(secondaryTitle) { advance() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
                    .disabled(isRequestingPermission)
                    .opacity(outcome == nil ? 1 : 0)
            } else {
                Color.clear.frame(height: 40)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .padding(.bottom, 12)
        // Deliberately opaque rather than a material: copy scrolling past must not show through.
        .background(Color(.systemBackground))
    }

    private var outcome: Outcome? { outcomes[step] }

    @ViewBuilder
    private var primaryLabel: some View {
        Text(content(for: step).primaryTitle)
            .font(.headline)
    }

    // MARK: - Actions

    private func performPrimaryAction() {
        switch step {
        case .welcome:
            advance()
        case .location:
            Task { await requestLocation() }
        case .notifications:
            Task { await requestNotifications() }
        }
    }

    private func requestLocation() async {
        isRequestingPermission = true
        let status = await locationManager.requestAuthorizationAwaitingDecision()
        isRequestingPermission = false
        let granted = status == .authorizedWhenInUse || status == .authorizedAlways
        await confirm(granted ? .granted : .declined)
    }

    private func requestNotifications() async {
        isRequestingPermission = true
        let granted = await NotificationManager.requestAuthorizationAwaitingDecision()
        isRequestingPermission = false
        await confirm(granted ? .granted : .declined)
    }

    /// Leaves the outcome visible on the button before advancing; the pause is only presentational,
    /// hence the much shorter one under Reduce Motion.
    private func confirm(_ result: Outcome) async {
        outcomes[step] = result
        UINotificationFeedbackGenerator().notificationOccurred(result == .granted ? .success : .warning)
        try? await Task.sleep(nanoseconds: reduceMotion ? 250_000_000 : 700_000_000)
        advance()
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(.smooth(duration: 0.35)) { step = previous }
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }

    // MARK: - Content

    private func content(for step: Step) -> OnboardingContent {
        switch step {
        case .welcome:
            return OnboardingContent(
                step: .welcome,
                themeColor: .blue,
                title: "Welcome to\nOpenVeloV",
                description: "An independent, unofficial client for Lyon's Vélo'v bike-share — not affiliated with JCDecaux or Grand Lyon.",
                bullets: [
                    .init(systemImage: "lock.open.fill", text: "Unlock or book a bike in seconds"),
                    .init(systemImage: "clock.arrow.circlepath", text: "Track your rides, ratings, and rewards")
                ],
                primaryTitle: "Get Started",
                secondaryTitle: nil
            )
        case .location:
            return OnboardingContent(
                step: .location,
                themeColor: .blue,
                title: "Find bikes\naround you",
                description: "Allow location access so we can show nearby stations, real-time availability, and walking directions to your bike.",
                bullets: [
                    .init(systemImage: "magnifyingglass", text: "See the closest available stations"),
                    .init(systemImage: "location.north.line.fill", text: "Get directions to your bike")
                ],
                primaryTitle: "Allow location access",
                secondaryTitle: "Not now"
            )
        case .notifications:
            return OnboardingContent(
                step: .notifications,
                themeColor: .red,
                title: "Stay in\nthe loop",
                description: "Turn on notifications so you never miss a booking hold, the end of your included ride time, or a docking alert.",
                bullets: [
                    .init(systemImage: "clock.fill", text: "Booking hold reminders"),
                    .init(systemImage: "bubble.left.fill", text: "Docking and end-of-ride alerts")
                ],
                primaryTitle: "Turn on notifications",
                secondaryTitle: "Maybe later"
            )
        }
    }
}

// MARK: - Content model

struct OnboardingContent {
    struct Bullet: Identifiable {
        let id = UUID()
        let systemImage: String
        let text: LocalizedStringKey
    }

    let step: OnboardingView.Step
    let themeColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let bullets: [Bullet]
    let primaryTitle: LocalizedStringKey
    let secondaryTitle: LocalizedStringKey?
}

// MARK: - Progress

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.blue : Color(.systemGray4))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(.smooth(duration: 0.35), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}

// MARK: - Page

private struct OnboardingPage: View {
    let content: OnboardingContent
    let isActive: Bool
    let illustrationHeight: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            if let illustrationHeight {
                illustration
                    .frame(height: illustrationHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 20)
                    .accessibilityHidden(true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // No hero icon above the title: it duplicated the illustration and pushed the
                    // last bullet off-screen.
                    VStack(alignment: .leading, spacing: 10) {
                        Text(content.title)
                            .font(.largeTitle.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .reveal(hasRevealed, index: 0, reduceMotion: reduceMotion)

                        Text(content.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .reveal(hasRevealed, index: 1, reduceMotion: reduceMotion)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(content.bullets.enumerated()), id: \.element.id) { index, bullet in
                            HStack(spacing: 12) {
                                Image(systemName: bullet.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(content.themeColor)
                                    .frame(width: 30, height: 30)
                                    .background(content.themeColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                Text(bullet.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .reveal(hasRevealed, index: 2 + index, reduceMotion: reduceMotion)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.top, 20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onChange(of: isActive) { _, active in
            // Clearing this on the way out is what makes the stagger replay if the rider swipes back.
            hasRevealed = active
        }
        .onAppear { hasRevealed = isActive }
    }

    @ViewBuilder
    private var illustration: some View {
        switch content.step {
        case .welcome: WelcomeIllustration(isActive: isActive)
        case .location: LocationIllustration(isActive: isActive)
        case .notifications: NotificationsIllustration(isActive: isActive)
        }
    }
}

// MARK: - Stagger

private extension View {
    func reveal(_ isRevealed: Bool, index: Int, reduceMotion: Bool) -> some View {
        opacity(isRevealed ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isRevealed ? 0 : 18))
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : .smooth(duration: 0.5).delay(0.12 + Double(index) * 0.07),
                value: isRevealed
            )
    }
}

#Preview {
    OnboardingView(locationManager: LocationManager()) {}
}
