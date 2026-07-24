import SwiftUI
import VLSKit

/// This banner shows at the bottom of the screen during a bike hold.
/// It uses the same layout as `ActiveTripBanner`, but with a blue theme.
/// The timer counts down to the end of the hold.
/// The banner has 2 actions: get directions to the station, and unlock the bike.
struct BookingBanner: View {
    let booking: Booking
    let stationName: String?
    let onDirections: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text(stationName ?? "Bike held for you")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(booking.endTime, style: .timer)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }

                Spacer(minLength: 4)

                if let standNumber = booking.standNumber {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Stand")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(standNumber)")
                            .font(.title3.bold())
                    }
                }
            }

            HStack(spacing: 10) {
                Button(action: onDirections) {
                    Label("Directions", systemImage: "figure.walk")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
                Button(action: onUnlock) {
                    Label("Unlock", systemImage: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
    }
}
