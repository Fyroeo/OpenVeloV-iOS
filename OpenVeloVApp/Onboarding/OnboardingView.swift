import SwiftUI

/// Shows permission priming screens before the system location and notification dialogs.
/// This lets the rider know why the app asks for each permission, instead of showing 2 OS prompts right after the app opens.
/// The "Allow" and "Turn On" buttons trigger the real system prompt. The text link below skips the prompt and moves to the next step. The app works either way.
struct OnboardingView: View {
    let locationManager: LocationManager
    let onFinish: () -> Void

    private enum Step: Int, CaseIterable {
        case welcome, location, notifications
    }

    private static let totalPages = Step.allCases.count

    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome: welcomeStep
            case .location: locationStep
            case .notifications: notificationsStep
            }
        }
        .animation(.snappy, value: step)
    }

    private var welcomeStep: some View {
        PrimingScreen(
            preview: { WelcomePreview() },
            themeColor: .blue,
            systemImage: "bicycle",
            title: "Welcome to\nOpenVeloV",
            description: "An independent, unofficial client for Lyon's Vélo'v bike-share — not affiliated with JCDecaux or Grand Lyon.",
            bullets: [
                (systemImage: "lock.open.fill", text: "Unlock or book a bike in seconds"),
                (systemImage: "clock.arrow.circlepath", text: "Track your rides, ratings, and rewards"),
            ],
            primaryTitle: "Get Started",
            skipTitle: nil,
            currentPage: 0,
            totalPages: Self.totalPages,
            onPrimary: { withAnimation { step = .location } },
            onSkip: nil
        )
    }

    private var locationStep: some View {
        PrimingScreen(
            preview: { MapPreview() },
            themeColor: .blue,
            systemImage: "mappin",
            title: "Find bikes\naround you",
            description: "Allow location access so we can show nearby stations, real-time availability, and turn-by-turn directions to your bike.",
            bullets: [
                (systemImage: "magnifyingglass", text: "See the closest available stations"),
                (systemImage: "location.north.line.fill", text: "Get directions to your bike"),
            ],
            primaryTitle: "Allow location access",
            skipTitle: "Not now",
            currentPage: 1,
            totalPages: Self.totalPages,
            onPrimary: {
                locationManager.requestAuthorization()
                withAnimation { step = .notifications }
            },
            onSkip: { withAnimation { step = .notifications } }
        )
    }

    private var notificationsStep: some View {
        PrimingScreen(
            preview: { NotificationsPreview() },
            themeColor: .red,
            systemImage: "bell.fill",
            title: "Stay in\nthe loop",
            description: "Turn on notifications so you never miss a booking hold, a ride reminder, or a docking alert.",
            bullets: [
                (systemImage: "clock.fill", text: "Booking hold reminders"),
                (systemImage: "bubble.left.fill", text: "Docking and end-of-ride alerts"),
            ],
            primaryTitle: "Turn on notifications",
            skipTitle: "Maybe later",
            currentPage: 2,
            totalPages: Self.totalPages,
            onPrimary: {
                NotificationManager.requestAuthorizationIfNeeded()
                onFinish()
            },
            onSkip: onFinish
        )
    }
}

/// Shared layout for a single onboarding page.
///
/// `themeColor` tints the hero icon and the bullet icons. The notifications page uses red, to read as an alert.
/// The primary button and the page dots always stay brand blue. The call-to-action must not change color from page to page.
private struct PrimingScreen<Preview: View>: View {
    @ViewBuilder let preview: () -> Preview
    let themeColor: Color
    let systemImage: String
    let title: String
    let description: String
    let bullets: [(systemImage: String, text: String)]
    let primaryTitle: String
    let skipTitle: String?
    let currentPage: Int
    let totalPages: Int
    let onPrimary: () -> Void
    let onSkip: (() -> Void)?

    private let brandColor = Color.blue

    var body: some View {
        VStack(spacing: 0) {
            preview()
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 20)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(themeColor, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(color: themeColor.opacity(0.35), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(bullets, id: \.text) { bullet in
                        HStack(spacing: 12) {
                            Image(systemName: bullet.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(themeColor)
                                .frame(width: 30, height: 30)
                                .background(themeColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            Text(bullet.text)
                                .font(.system(size: 14.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
                .clipShape(RoundedRectangle(cornerRadius: 15))

                if let skipTitle, let onSkip {
                    Button(skipTitle, action: onSkip)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

                HStack(spacing: 7) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? brandColor : Color(.systemGray4))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 26)
            .padding(.top, 4)
        }
    }
}

private struct WelcomePreview: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                LinearGradient(
                    colors: [Color.blue, Color(red: 0.2, green: 0.6, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: w * 0.6)
                    .position(x: w * 0.08, y: h * 0.05)

                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: w * 0.45)
                    .position(x: w * 0.95, y: h * 0.95)

                Image(systemName: "bicycle")
                    .font(.system(size: 88, weight: .semibold))
                    .foregroundStyle(.white)
                    .position(x: w * 0.5, y: h * 0.46)

                LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .init(x: 0.5, y: 0.6), endPoint: .bottom)
            }
        }
    }
}

/// A stylized stand-in for a map. It does not use real MapKit data.
private struct MapPreview: View {
    private let landColor = Color(red: 0.914, green: 0.925, blue: 0.882) // #e9ece1
    private let waterColor = Color(red: 0.663, green: 0.847, blue: 0.937) // #a9d8ef
    private let parkColor = Color(red: 0.812, green: 0.902, blue: 0.706) // #cfe6b4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                landColor

                Rectangle()
                    .fill(waterColor)
                    .frame(width: w * 0.34, height: h * 2.4)
                    .rotationEffect(.degrees(-14))
                    .position(x: w * 0.68, y: h * 0.5)

                RoundedRectangle(cornerRadius: 20)
                    .fill(parkColor)
                    .frame(width: w * 0.28, height: h * 0.22)
                    .position(x: w * 0.2, y: h * 0.21)

                RoundedRectangle(cornerRadius: 22)
                    .fill(parkColor)
                    .frame(width: w * 0.24, height: h * 0.26)
                    .position(x: w * 0.2, y: h * 0.81)

                street(width: 6, length: h * 1.3, rotation: 11)
                    .position(x: w * 0.26, y: h * 0.5)
                street(width: 6, length: h * 1.3, rotation: -8)
                    .position(x: w * 0.72, y: h * 0.5)
                street(width: 6, length: w * 1.3, rotation: 5)
                    .position(x: w * 0.5, y: h * 0.38)

                pin(color: .green, x: w * 0.25, y: h * 0.22)
                pin(color: .orange, x: w * 0.78, y: h * 0.16)
                pin(color: .green, x: w * 0.82, y: h * 0.68)
                pin(color: .green, x: w * 0.22, y: h * 0.78)

                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 46, height: 46)
                    .position(x: w * 0.44, y: h * 0.52)
                Circle()
                    .fill(Color.blue)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    .position(x: w * 0.44, y: h * 0.52)

                LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .init(x: 0.5, y: 0.55), endPoint: .bottom)
            }
        }
    }

    private func street(width: CGFloat, length: CGFloat, rotation: Double) -> some View {
        Rectangle()
            .fill(.white)
            .frame(width: width, height: length)
            .rotationEffect(.degrees(rotation))
    }

    private func pin(color: Color, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: "mappin.circle.fill")
            .font(.title2)
            .foregroundStyle(.white, color)
            .shadow(radius: 2)
            .position(x: x, y: y)
    }
}

/// Preview cards for the notifications the app sends: booking hold, ride-ending alert, and post-ride summary.
private struct NotificationsPreview: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.918, green: 0.953, blue: 1.0), Color(red: 0.953, green: 0.969, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 11) {
                NotificationCard(iconBackground: .blue, systemImage: "bicycle", title: "Bike reserved", subtitle: "Held for 10 min · Dock 5, Ainay", time: "now")
                    .rotationEffect(.degrees(-1.5))

                NotificationCard(iconBackground: .orange, systemImage: "clock.fill", title: "Ride ending soon", subtitle: "Find a dock to avoid extra fees", time: "2m")
                    .rotationEffect(.degrees(1.2))
                    .padding(.leading, 14)

                NotificationCard(iconBackground: .green, systemImage: "checkmark", title: "Ride complete", subtitle: "17 min · €2.40 · 4.2 km", time: "1h")
                    .rotationEffect(.degrees(-0.8))
                    .opacity(0.85)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .init(x: 0.5, y: 0.55), endPoint: .bottom)
        }
    }
}

private struct NotificationCard: View {
    let iconBackground: Color
    let systemImage: String
    let title: String
    let subtitle: String
    let time: String

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(iconBackground, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(time)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground).opacity(0.95), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 0, green: 0.235, blue: 0.549).opacity(0.1), radius: 9, y: 3)
    }
}
