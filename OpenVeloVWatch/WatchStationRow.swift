import CoreLocation
import SwiftUI

struct WatchStationRow: View {
    let station: WatchStation
    let distance: CLLocationDistance?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(station.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if let distance {
                    Text(watchDistanceText(distance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                countChip(icon: "bicycle", value: station.mechanical, tint: .red)
                countChip(icon: "bolt.fill", value: station.electric, tint: .green)
                countChip(icon: "parkingsign", value: station.docks, tint: .secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.name): \(station.mechanical) mechanical, \(station.electric) electric, \(station.docks) docks")
    }

    private func countChip(icon: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.caption2)
            Text("\(value)").font(.caption.weight(.semibold).monospacedDigit())
        }
        .foregroundStyle(tint)
    }
}
