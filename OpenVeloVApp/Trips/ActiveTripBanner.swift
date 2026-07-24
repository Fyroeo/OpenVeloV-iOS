import SwiftUI
import VLSKit

/// This card shows at the bottom of the screen during a ride. It shows the elapsed time,
/// the bike information, and 2 actions: find the nearest dock, or request 15 extra minutes.
///
/// This card does not show a live fare or distance. The API sends neither value during
/// a ride, and the app does not track GPS position. The app does not guess these values.
///
/// There is no "end ride" call. A ride ends only when the rider docks the bike.
/// This is why the main action is "Nearest dock", not "End ride".
struct ActiveTripBanner: View {
    let trip: Trip
    let onNearestDock: () -> Void
    let onExtraTime: () -> Void

    private var typeColor: Color { trip.bikeType == .electrical ? .green : .red }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: trip.bikeType == .electrical ? "bolt.fill" : "bicycle")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(typeColor, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(trip.startDateTime ?? Date(), style: .timer)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(trip.bikeType == .electrical ? "Electric" : "Mechanical")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let start = trip.startDateTime {
                        Text(start, format: .dateTime.hour().minute())
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onExtraTime) {
                    Label("+15 min", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                Button(action: onNearestDock) {
                    Label("Nearest dock", systemImage: "parkingsign")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
    }

    private var statusText: String {
        if let number = trip.bikeNumber {
            return "Riding · Bike #\(number)"
        }
        return "Riding"
    }
}
