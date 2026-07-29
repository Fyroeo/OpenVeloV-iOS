import SwiftUI

struct StationMarkerView: View {
    let station: MapStation
    let numberMode: MapNumberMode
    var isFavorite: Bool = false
    var hasBonus: Bool = false
    var isSelected: Bool = false

    private var count: Int { numberMode.count(for: station) }

    private var tint: Color {
        guard numberMode.isAvailable(at: station) else { return .gray }
        return numberMode.availability(for: station).color
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint, in: Capsule())
                .overlay {
                    if isSelected {
                        Capsule().strokeBorder(Color.primary, lineWidth: 2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                            .padding(2)
                            .background(.white, in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if hasBonus {
                        Image(systemName: "plus")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(Color.purple, in: Circle())
                            .offset(x: -5, y: -5)
                    }
                }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(tint)
                .offset(y: -4)
        }
        .scaleEffect(isSelected ? 1.18 : 1)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [station.name, "\(count) \(numberMode.unitLabel)"]
        if !numberMode.isAvailable(at: station) {
            parts.append(numberMode == .parking ? String(localized: "not accepting returns") : String(localized: "closed"))
        }
        if hasBonus { parts.append(String(localized: "bonus station")) }
        if isFavorite { parts.append(String(localized: "favorite")) }
        return parts.joined(separator: ", ")
    }
}

struct StationClusterMarkerView: View {
    let cluster: MapCluster
    let numberMode: MapNumberMode
    var containsFavorite: Bool = false

    private var tint: Color {
        guard cluster.isAvailable(for: numberMode) else { return .gray }
        return cluster.availability(for: numberMode).color
    }

    private var diameter: CGFloat {
        switch cluster.stations.count {
        case ..<4: return 38
        case ..<9: return 44
        default: return 50
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: diameter, height: diameter)
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                .frame(width: diameter, height: diameter)

            VStack(spacing: -1) {
                Text("\(cluster.count(for: numberMode))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(cluster.stations.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .overlay(alignment: .leading) {
                        Image(systemName: "mappin")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .offset(x: -8)
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            if containsFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                    .padding(2)
                    .background(.white, in: Circle())
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(cluster.stations.count) stations, \(cluster.count(for: numberMode)) \(numberMode.unitLabel) total. Double tap to zoom in."))
        .accessibilityAddTraits(.isButton)
    }
}
