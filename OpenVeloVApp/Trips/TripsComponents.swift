import SwiftUI
import VLSKit

struct TripRow: View {
    let trip: Trip
    let stationNames: [Int: String]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.bikeType == .electrical ? "bolt.fill" : "bicycle")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(trip.bikeType == .electrical ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(routeText(for: trip, stationNames: stationNames))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let start = trip.startDateTime {
                        Text(start, format: .dateTime.day().month().hour().minute())
                    }
                    if let duration = formattedDuration(for: trip) {
                        Text("· \(duration)")
                    }
                    if let priceText = priceText(for: trip) {
                        Text("· \(priceText)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let status = trip.status {
                    Text(status.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(status.tintColor)
                }
                if canBeRated {
                    Label(trip.isRated == true ? LocalizedStringKey("Rated") : LocalizedStringKey("Unrated"), systemImage: trip.isRated == true ? "star.fill" : "star")
                        .font(.caption2)
                        .foregroundStyle(trip.isRated == true ? .yellow : .secondary)
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var canBeRated: Bool {
        trip.status == .finished || trip.status == .autoFinished
    }
}

struct RideStatsCard: View {
    let trips: [Trip]

    private var completedTrips: [Trip] {
        trips.filter { $0.status == .finished || $0.status == .autoFinished }
    }

    private var totalDuration: TimeInterval {
        completedTrips.reduce(0) { total, trip in
            guard let start = trip.startDateTime, let end = trip.endDateTime else { return total }
            return total + end.timeIntervalSince(start)
        }
    }

    private var electricCount: Int {
        completedTrips.filter { $0.bikeType == .electrical }.count
    }

    private var mechanicalCount: Int {
        completedTrips.filter { $0.bikeType != .electrical }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            stat(value: "\(completedTrips.count)", label: "Rides")
            Divider().frame(height: 36)
            stat(value: totalDurationText, label: "Total time")
            Divider().frame(height: 36)
            stat(value: "\(mechanicalCount)/\(electricCount)", label: "Mech / Elec")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var totalDurationText: String {
        let totalMinutes = Int(totalDuration / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)"
        }
        return "\(totalMinutes)m"
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
