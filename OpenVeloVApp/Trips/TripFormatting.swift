import SwiftUI
import VLSKit

func stationName(forNumber number: Int?, in names: [Int: String]) -> String? {
    guard let number else { return nil }
    return names[number] ?? String(localized: "Station \(number.identifierText)")
}

func routeText(for trip: Trip, stationNames: [Int: String]) -> String {
    let start = trip.startStationName ?? stationName(forNumber: trip.startStation, in: stationNames) ?? String(localized: "Unknown station")
    let end = trip.endStationName ?? stationName(forNumber: trip.endStation, in: stationNames)
    guard let end, end != start else {
        return start
    }
    return "\(start) → \(end)"
}

func formattedDuration(for trip: Trip) -> String? {
    guard let start = trip.startDateTime, let end = trip.endDateTime else { return nil }
    return durationFormatter.string(from: end.timeIntervalSince(start))
}

/// The API reports `price`, `reducedPrice`, and `discount` in cents, and has only ever returned `0`.
func currencyText(_ minorUnits: Int64) -> String {
    let amount = Decimal(minorUnits) / 100
    return amount.formatted(.currency(code: "EUR"))
}

func priceText(for trip: Trip) -> String? {
    guard let price = trip.price else { return nil }
    return price == 0 ? String(localized: "Free", comment: "A ride that cost nothing") : currencyText(price)
}

extension Trip.Status {
    var label: String {
        switch self {
        case .requested: return String(localized: "Requested")
        case .started: return String(localized: "In Progress")
        case .finished, .autoFinished: return String(localized: "Finished")
        case .rejected: return String(localized: "Rejected")
        case .timeout: return String(localized: "Timed Out")
        case .paused: return String(localized: "Paused")
        case .error: return String(localized: "Error")
        case .warning: return String(localized: "Warning")
        case .reversed: return String(localized: "Reversed")
        }
    }

    var tintColor: Color {
        switch self {
        case .finished, .autoFinished: return .secondary
        case .started, .requested: return .green
        case .rejected, .error, .timeout: return .red
        case .paused, .warning: return .orange
        case .reversed: return .secondary
        }
    }
}

let durationFormatter: DateComponentsFormatter = {
    let f = DateComponentsFormatter()
    f.allowedUnits = [.hour, .minute, .second]
    f.unitsStyle = .abbreviated
    f.maximumUnitCount = 2
    return f
}()
