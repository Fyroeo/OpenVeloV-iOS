import SwiftUI
import VLSKit

struct BikeRowView: View {
    let bike: Bike
    var isBooked: Bool = false
    var isRecommended: Bool = false

    // The server's own `statusLabel` labels both available and reserved bikes "Accroché", so the
    // text is derived from `status` instead, which also keeps it consistent with `statusColor`.
    private var statusText: String {
        switch bike.status {
        case .available: return String(localized: "Available")
        case .reserved: return String(localized: "Reserved")
        case .rented, .rentedMinuteDepose: return String(localized: "Rented")
        case .maintenance: return String(localized: "Maintenance")
        case .blocked: return String(localized: "Blocked")
        case .stolen: return String(localized: "Stolen")
        case .unreachable: return String(localized: "Unreachable")
        case .waitingForBinding, .tested, .validated: return String(localized: "Being set up")
        case .deleted, .poweredOff: return String(localized: "Off")
        case .unknown: return String(localized: "Unknown")
        }
    }

    private var statusColor: Color {
        switch bike.status {
        case .available: return .green
        case .rented, .rentedMinuteDepose: return .secondary
        case .maintenance, .blocked, .unreachable, .stolen: return .red
        default: return .orange
        }
    }

    /// Matches the capacity-bar legend on the station sheet, where mechanical bikes are the red
    /// segment and electric ones the green.
    private var typeColor: Color {
        bike.type == .electrical ? .green : .red
    }

    var body: some View {
        HStack(spacing: 12) {
            standBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: bike.type == .electrical ? "bolt.fill" : "bicycle")
                        .foregroundStyle(typeColor)
                    Text("#\(bike.number.identifierText)")
                        .font(.subheadline.bold())
                    if isRecommended && !isBooked {
                        Text("BEST PICK")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                HStack(spacing: 4) {
                    if isBooked {
                        Label("Booked", systemImage: "clock.badge.checkmark")
                            .foregroundStyle(.blue)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    } else {
                        Text(statusText)
                            .foregroundStyle(statusColor)
                    }
                    if !isBooked, let value = bike.rating.value {
                        Text("·").foregroundStyle(.secondary)
                        starsView(for: value)
                        if let lastRatingDateTime = bike.rating.lastRatingDateTime {
                            Text(lastRatingDateTime, format: .relative(presentation: .named))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.caption)
            }

            Spacer()

            if let battery = bike.battery {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(for: battery.percentage))
                    Text("\(battery.percentage)%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isBooked ? Color.blue.opacity(0.12) : Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(bike.status == .available || isBooked ? .isButton : [])
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let standNumber = bike.standNumber { parts.append(String(localized: "Stand \(standNumber.identifierText)")) }
        parts.append(String(localized: "bike number \(bike.number.identifierText)"))
        parts.append(bike.type == .electrical ? String(localized: "electric") : String(localized: "mechanical"))
        parts.append(isBooked ? String(localized: "booked by you") : statusText.lowercased())
        if let battery = bike.battery { parts.append(String(localized: "\(battery.percentage) percent battery")) }
        if let value = bike.rating.value { parts.append(String(localized: "\(Int(value)) percent recommended")) }
        if isRecommended && !isBooked { parts.append(String(localized: "best pick")) }
        return parts.joined(separator: ", ")
    }

    private var standBadge: some View {
        Text(bike.standNumber.map(String.init) ?? "–")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(typeColor, in: RoundedRectangle(cornerRadius: 9))
    }

    private func starsView(for value: Double) -> some View {
        let filledStars = Int((value / 100 * 3).rounded())
        return HStack(spacing: 1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < filledStars ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func batteryIcon(for percentage: Int) -> String {
        switch percentage {
        case ..<20: return "battery.0"
        case ..<40: return "battery.25"
        case ..<60: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }
}
