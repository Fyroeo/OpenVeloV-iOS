import SwiftUI

// Drawn in SwiftUI rather than shipped as assets. Each replays its entrance whenever the
// rider lands on the page, idles only while on screen, and falls back to a plain fade
// under Reduce Motion.

// MARK: - Welcome

struct WelcomeIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasEntered = false
    @State private var isFloating = false

    private struct Pill: Identifiable {
        let id = UUID()
        let count: Int
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let delay: Double
    }

    private let pills: [Pill] = [
        Pill(count: 12, color: .green, x: 0.20, y: 0.24, delay: 0.18),
        Pill(count: 3, color: .orange, x: 0.78, y: 0.19, delay: 0.30),
        Pill(count: 8, color: .green, x: 0.83, y: 0.63, delay: 0.42),
        Pill(count: 0, color: .red, x: 0.16, y: 0.66, delay: 0.54)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                LinearGradient(
                    colors: [Color.blue, Color(red: 0.20, green: 0.58, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: size.width * 0.62)
                    .position(x: size.width * 0.10, y: size.height * 0.08)
                    .offset(y: isFloating ? 14 : -14)
                Circle()
                    .fill(.white.opacity(0.10))
                    .frame(width: size.width * 0.46)
                    .position(x: size.width * 0.94, y: size.height * 0.92)
                    .offset(y: isFloating ? -18 : 18)

                Image(systemName: "bicycle")
                    .font(.system(size: min(size.width * 0.30, 96), weight: .semibold))
                    .foregroundStyle(.white)
                    .position(x: size.width * 0.5, y: size.height * 0.46)
                    .offset(y: isFloating ? -6 : 6)
                    .scaleEffect(hasEntered ? 1 : 0.72)
                    .opacity(hasEntered ? 1 : 0)

                ForEach(pills) { pill in
                    availabilityPill(pill)
                        .position(x: size.width * pill.x, y: size.height * pill.y)
                        .scaleEffect(hasEntered ? 1 : 0.1)
                        .opacity(hasEntered ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.3)
                                : .spring(response: 0.5, dampingFraction: 0.6).delay(pill.delay),
                            value: hasEntered
                        )
                }

                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .init(x: 0.5, y: 0.62),
                    endPoint: .bottom
                )
            }
        }
        .onChange(of: isActive) { _, active in update(active) }
        .onAppear { update(isActive) }
    }

    private func availabilityPill(_ pill: Pill) -> some View {
        Text("\(pill.count)")
            .font(.caption.bold())
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(pill.color, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.65), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private func update(_ active: Bool) {
        guard active else {
            hasEntered = false
            isFloating = false
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.7)) {
            hasEntered = true
        }
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            isFloating = true
        }
    }
}

// MARK: - Location

struct LocationIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasEntered = false
    @State private var isPulsing = false

    private let landColor = Color(red: 0.914, green: 0.925, blue: 0.882)
    private let waterColor = Color(red: 0.663, green: 0.847, blue: 0.937)
    private let parkColor = Color(red: 0.812, green: 0.902, blue: 0.706)

    private struct Pin: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let delay: Double
    }

    private let pins: [Pin] = [
        Pin(color: .green, x: 0.25, y: 0.22, delay: 0.20),
        Pin(color: .orange, x: 0.78, y: 0.16, delay: 0.32),
        Pin(color: .green, x: 0.82, y: 0.66, delay: 0.44),
        Pin(color: .green, x: 0.22, y: 0.74, delay: 0.56)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                landColor

                Rectangle()
                    .fill(waterColor)
                    .frame(width: size.width * 0.34, height: size.height * 2.4)
                    .rotationEffect(.degrees(-14))
                    .position(x: size.width * 0.68, y: size.height * 0.5)

                RoundedRectangle(cornerRadius: 20)
                    .fill(parkColor)
                    .frame(width: size.width * 0.28, height: size.height * 0.22)
                    .position(x: size.width * 0.2, y: size.height * 0.21)

                RoundedRectangle(cornerRadius: 22)
                    .fill(parkColor)
                    .frame(width: size.width * 0.24, height: size.height * 0.26)
                    .position(x: size.width * 0.2, y: size.height * 0.81)

                street(width: 6, length: size.height * 1.3, rotation: 11)
                    .position(x: size.width * 0.26, y: size.height * 0.5)
                street(width: 6, length: size.height * 1.3, rotation: -8)
                    .position(x: size.width * 0.72, y: size.height * 0.5)
                street(width: 6, length: size.width * 1.3, rotation: 5)
                    .position(x: size.width * 0.5, y: size.height * 0.38)

                ForEach(pins) { pin in
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, pin.color)
                        .shadow(radius: 2)
                        .position(x: size.width * pin.x, y: size.height * pin.y)
                        .offset(y: hasEntered ? 0 : -26)
                        .opacity(hasEntered ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.3)
                                : .spring(response: 0.45, dampingFraction: 0.55).delay(pin.delay),
                            value: hasEntered
                        )
                }

                userDot(in: size)

                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .init(x: 0.5, y: 0.58),
                    endPoint: .bottom
                )
            }
        }
        .onChange(of: isActive) { _, active in update(active) }
        .onAppear { update(isActive) }
    }

    private func userDot(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.22))
                .frame(width: 46, height: 46)
                .scaleEffect(isPulsing ? 2.1 : 1)
                .opacity(isPulsing ? 0 : 0.9)

            Circle()
                .fill(Color.blue)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .position(x: size.width * 0.44, y: size.height * 0.52)
        .scaleEffect(hasEntered ? 1 : 0.4)
        .opacity(hasEntered ? 1 : 0)
    }

    private func street(width: CGFloat, length: CGFloat, rotation: Double) -> some View {
        Rectangle()
            .fill(.white)
            .frame(width: width, height: length)
            .rotationEffect(.degrees(rotation))
    }

    private func update(_ active: Bool) {
        guard active else {
            hasEntered = false
            isPulsing = false
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.75)) {
            hasEntered = true
        }
        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
            isPulsing = true
        }
    }
}

// MARK: - Notifications

struct NotificationsIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealedCards = 0
    @State private var isFloating = false

    private struct Card: Identifiable {
        let id = UUID()
        let background: Color
        let systemImage: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let time: LocalizedStringKey
        let tilt: Double
        let indent: CGFloat
    }

    private let cards: [Card] = [
        Card(background: .blue, systemImage: "bicycle", title: "Bike reserved",
             subtitle: "Held for you · Stand 5, Ainay", time: "now", tilt: -1.5, indent: 0),
        Card(background: .orange, systemImage: "clock.fill", title: "Ride ending soon",
             subtitle: "Find a dock to avoid extra fees", time: "2m", tilt: 1.2, indent: 14),
        Card(background: .green, systemImage: "checkmark", title: "Ride complete",
             subtitle: "17 min · Bike #25391 docked", time: "1h", tilt: -0.8, indent: 0)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 11) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    notificationCard(card)
                        .rotationEffect(.degrees(card.tilt))
                        .padding(.leading, card.indent)
                        .opacity(index < revealedCards ? 1 : 0)
                        .offset(
                            x: index < revealedCards ? 0 : 70,
                            y: isFloating ? -3 : 3
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .init(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
        }
        .onChange(of: isActive) { _, active in update(active) }
        .onAppear { update(isActive) }
    }

    private func notificationCard(_ card: Card) -> some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: card.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(card.background, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(card.title)
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                Text(card.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(card.time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 9, y: 3)
    }

    private func update(_ active: Bool) {
        guard active else {
            revealedCards = 0
            isFloating = false
            return
        }
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.3)) { revealedCards = cards.count }
            return
        }
        revealedCards = 0
        for index in cards.indices {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.15 + Double(index) * 0.14)) {
                revealedCards = index + 1
            }
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            isFloating = true
        }
    }
}
