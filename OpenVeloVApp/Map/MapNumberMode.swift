import SwiftUI

/// The count that a `StationMarkerView` pin shows.
/// The user can switch modes from the map toolbar.
enum MapNumberMode: String, CaseIterable, Identifiable {
    case all
    case electrical
    case parking

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .all: return "bicycle"
        case .electrical: return "bolt.fill"
        case .parking: return "parkingsign"
        }
    }

    var label: String {
        switch self {
        case .all: return "All bikes"
        case .electrical: return "Electric bikes"
        case .parking: return "Parking spots"
        }
    }

    /// Short label for the segmented control.
    var shortLabel: String {
        switch self {
        case .all: return "Bikes"
        case .electrical: return "E-bikes"
        case .parking: return "Docks"
        }
    }

    /// The noun for the counted item. Views use it in list rows, for example "22 docks".
    var unitLabel: String {
        self == .parking ? "docks" : "bikes"
    }

    func count(for station: MapStation) -> Int {
        switch self {
        case .all: return station.totalBikes
        case .electrical: return station.electricalBikes
        case .parking: return station.docksAvailable
        }
    }

    /// True if the station can currently do this mode's action.
    /// The action is renting a bike or returning a bike.
    /// Views use this value to show a greyed-out pin when the action is not available.
    func isAvailable(at station: MapStation) -> Bool {
        self == .parking ? station.isReturning : station.isRenting
    }

    func availability(for station: MapStation) -> AvailabilityLevel {
        guard isAvailable(at: station) else { return .none }
        switch count(for: station) {
        case 0: return .none
        case 1...3: return .few
        default: return .plenty
        }
    }
}

/// A coarse availability bucket for a station.
/// The map pins, the legend, and the nearby-stations list all share this value.
/// This keeps the color coding the same everywhere.
enum AvailabilityLevel: CaseIterable {
    case plenty
    case few
    case none

    var color: Color {
        switch self {
        case .plenty: return .green
        case .few: return .orange
        case .none: return .red
        }
    }

    var label: String {
        switch self {
        case .plenty: return "Plenty"
        case .few: return "Few"
        case .none: return "None"
        }
    }
}
