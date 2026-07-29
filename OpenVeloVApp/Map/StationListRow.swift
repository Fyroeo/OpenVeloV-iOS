import SwiftUI

struct StationListRow: View {
    let station: MapStation
    var userLocation: UserLocation?
    var isFavorite: Bool = false
    var hasBonus: Bool = false

    private var distance: Double? { station.distance(from: userLocation) }

    var body: some View {
        HStack(spacing: 12) {
            availabilityBadge

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Text(station.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                countsRow

                if !station.isRenting || hasBonus {
                    HStack(spacing: 8) {
                        if !station.isRenting {
                            Label("Closed", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        }
                        if hasBonus {
                            Label("Bonus station", systemImage: "plus.circle.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                }
            }
            // Together with the `fixedSize` calls on the counts and the distance, this leaves the
            // name as the only element that gives up width.
            .frame(maxWidth: .infinity, alignment: .leading)

            if let distance {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MapStation.distanceText(distance))
                        .font(.caption.weight(.semibold))
                    if let walkingTime = MapStation.walkingTimeText(for: distance) {
                        Text(walkingTime)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var countsRow: some View {
        HStack(spacing: 12) {
            count(station.mechanicalBikes, systemImage: "bicycle", tint: .red)
            count(station.electricalBikes, systemImage: "bolt.fill", tint: .green)
            count(station.docksAvailable, systemImage: "parkingsign", tint: .secondary)
        }
        .font(.caption)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func count(_ value: Int, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            Text("\(value)")
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .lineLimit(1)
    }

    /// Reuses the map pin's availability colour so the list and the map agree at a glance.
    private var availabilityBadge: some View {
        let level = MapNumberMode.all.availability(for: station)
        return ZStack {
            Circle()
                .fill(level.color.opacity(0.16))
                .frame(width: 38, height: 38)
            Text("\(station.totalBikes)")
                .font(.subheadline.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 3)
                .foregroundStyle(level.color)
        }
        .fixedSize()
    }

    private var accessibilityLabel: String {
        var parts = [station.name]
        if let distance {
            if MapStation.walkingTimeText(for: distance) != nil {
                parts.append(String(localized: "\(MapStation.distanceText(distance)) away, about \(MapStation.walkingMinutes(for: distance)) minutes walk"))
            } else {
                parts.append(String(localized: "\(MapStation.distanceText(distance)) away"))
            }
        }
        parts.append(String(localized: "\(station.mechanicalBikes) mechanical, \(station.electricalBikes) electric, \(station.docksAvailable) free docks"))
        if !station.isRenting { parts.append(String(localized: "closed")) }
        if hasBonus { parts.append(String(localized: "bonus station")) }
        if isFavorite { parts.append(String(localized: "favorite")) }
        return parts.joined(separator: ". ")
    }
}
