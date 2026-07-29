import ActivityKit
import WidgetKit
import SwiftUI

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            let tint = context.state.typeColor
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BikeBadge(isElectric: context.state.isElectric, size: 40, cornerRadius: 12, iconFont: .body.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.state.startDate, style: .timer)
                            .font(.title3.monospacedDigit().bold())
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(tint)
                            .frame(width: 64, alignment: .trailing)
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.secondary)
                        Text("Bike #\(context.state.bikeNumber.identifierText) · \(context.state.stationName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isElectric ? "bolt.fill" : "bicycle")
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(context.state.startDate, style: .timer)
                    .font(.caption2.monospacedDigit().bold())
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(tint)
                    .frame(width: 42, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isElectric ? "bolt.fill" : "bicycle")
                    .foregroundStyle(tint)
            }
        }
    }
}

extension TripActivityAttributes.ContentState {
    var typeColor: Color { isElectric ? .green : .red }
}

/// Deliberately mirrors the bike icon in the main app's `ActiveTripBanner`; change both together
/// or the Live Activity and the in-app banner stop looking like the same thing.
struct BikeBadge: View {
    let isElectric: Bool
    var size: CGFloat = 52
    var cornerRadius: CGFloat = 16
    var iconFont: Font = .title2.bold()

    var body: some View {
        Image(systemName: isElectric ? "bolt.fill" : "bicycle")
            .font(iconFont)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background((isElectric ? Color.green : Color.red).gradient, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct LockScreenView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            BikeBadge(isElectric: state.isElectric)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("Riding")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(state.startDate, style: .timer)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                (state.isElectric ? Text("Electric") : Text("Mechanical"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(state.typeColor)
                Text("Bike #\(state.bikeNumber.identifierText)")
                    .font(.subheadline.weight(.semibold))
                Text(state.stationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}

#Preview("Notification", as: .content, using: TripActivityAttributes()) {
    TripLiveActivity()
} contentStates: {
    TripActivityAttributes.ContentState(startDate: .now.addingTimeInterval(-410), bikeNumber: 52284, stationName: "Perrache / Carnot", isElectric: true)
    TripActivityAttributes.ContentState(startDate: .now.addingTimeInterval(-70), bikeNumber: 24572, stationName: "Bellecour", isElectric: false)
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: TripActivityAttributes()) {
    TripLiveActivity()
} contentStates: {
    TripActivityAttributes.ContentState(startDate: .now.addingTimeInterval(-410), bikeNumber: 52284, stationName: "Perrache / Carnot", isElectric: true)
}
