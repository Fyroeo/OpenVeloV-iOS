import ActivityKit
import WidgetKit
import SwiftUI

/// Vélo'v holds a booked bike for 15 minutes.
/// The server data does not include this duration.
/// The code assumes a fixed value of 15 minutes to set the start point of the progress bar.
private let bookingHoldDuration: TimeInterval = 15 * 60

struct BookingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BookingActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BookingBadge(isElectric: context.state.isElectric, size: 40, iconFont: .body.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title3.monospacedDigit().bold())
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.blue)
                        .frame(width: 64, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(timerInterval: context.state.endDate.addingTimeInterval(-bookingHoldDuration)...context.state.endDate, countsDown: true)
                            .tint(.blue)
                            .labelsHidden()
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            Text(context.state.stationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if let standNumber = context.state.standNumber {
                                StandBadge(standNumber: standNumber)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .font(.caption2.monospacedDigit().bold())
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.blue)
                    .frame(width: 42, alignment: .trailing)
            } minimal: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

/// This badge shows the stand number by itself, not inside a sentence.
/// The rider needs the stand number to find the correct physical dock.
private struct StandBadge: View {
    let standNumber: Int

    var body: some View {
        Text("Stand \(standNumber)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue, in: Capsule())
    }
}

/// A clock icon leads this badge, not the bike icon.
/// This badge shows a countdown, not a bike.
/// The bike type appears as a small secondary badge only.
/// The badge color is always blue. Blue is the color for a booking.
/// TripLiveActivity.swift shows green for an electric bike and red for a mechanical bike instead.
private struct BookingBadge: View {
    let isElectric: Bool
    var size: CGFloat = 52
    var iconFont: Font = .title2.bold()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "clock.fill")
                .font(iconFont)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: size * 0.3))
            Image(systemName: isElectric ? "bolt.fill" : "bicycle")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(.blue)
                .padding(size * 0.08)
                .background(Color(.systemBackground), in: Circle())
                .offset(x: size * 0.08, y: size * 0.08)
        }
    }
}

private struct LockScreenView: View {
    let state: BookingActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                BookingBadge(isElectric: state.isElectric)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Bike held for you")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Bike #\(state.bikeNumber)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }

                Spacer(minLength: 8)

                Text(state.endDate, style: .timer)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.blue)
            }

            ProgressView(timerInterval: state.endDate.addingTimeInterval(-bookingHoldDuration)...state.endDate, countsDown: true)
                .tint(.blue)
                .labelsHidden()

            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.stationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let standNumber = state.standNumber {
                    StandBadge(standNumber: standNumber)
                }
            }
        }
        .padding(16)
    }
}

#Preview("Notification", as: .content, using: BookingActivityAttributes()) {
    BookingLiveActivity()
} contentStates: {
    BookingActivityAttributes.ContentState(endDate: .now.addingTimeInterval(480), bikeNumber: 52284, stationName: "Perrache / Carnot", standNumber: 12, isElectric: true)
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: BookingActivityAttributes()) {
    BookingLiveActivity()
} contentStates: {
    BookingActivityAttributes.ContentState(endDate: .now.addingTimeInterval(480), bikeNumber: 52284, stationName: "Perrache / Carnot", standNumber: 12, isElectric: true)
}
