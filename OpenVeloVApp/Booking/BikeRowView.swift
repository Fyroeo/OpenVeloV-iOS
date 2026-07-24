import SwiftUI
import VLSKit

struct BikeRowView: View {
    let bike: Bike
    var isBooked: Bool = false

    // The server field `statusLabel` (for example, "Accroché") shows only if a bike is
    // docked. It does not show if the bike is available to rent.
    // An AVAILABLE bike and a RESERVED bike both get the label "Accroché" from the server.
    // This code builds its own text from `status`. This keeps the displayed text and
    // color consistent with each other.
    private var statusText: String {
        switch bike.status {
        case .available: return "Available"
        case .reserved: return "Reserved"
        case .rented, .rentedMinuteDepose: return "Rented"
        case .maintenance: return "Maintenance"
        case .blocked: return "Blocked"
        case .stolen: return "Stolen"
        case .unreachable: return "Unreachable"
        case .waitingForBinding, .tested, .validated: return "Being set up"
        case .deleted, .poweredOff: return "Off"
        case .unknown: return "Unknown"
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

    /// This color matches the legend on the capacity bar.
    /// Mechanical bikes are red. Electric bikes are green.
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
                    Text("#\(bike.number)")
                        .font(.subheadline.bold())
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
