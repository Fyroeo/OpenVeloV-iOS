import SwiftUI

/// The count that a `StationMarkerView` pin shows.
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
        case .all: return String(localized: "All bikes")
        case .electrical: return String(localized: "Electric bikes")
        case .parking: return String(localized: "Parking spots")
        }
    }

    var shortLabel: String {
        switch self {
        case .all: return String(localized: "Bikes", comment: "Segmented control: show bike counts on the map")
        case .electrical: return String(localized: "E-bikes", comment: "Segmented control: show electric bike counts")
        case .parking: return String(localized: "Docks", comment: "Segmented control: show free dock counts")
        }
    }

    var unitLabel: String {
        self == .parking
            ? String(localized: "docks", comment: "Plural noun used mid-sentence, e.g. '22 docks'")
            : String(localized: "bikes", comment: "Plural noun used mid-sentence, e.g. '22 bikes'")
    }

    func count(for station: MapStation) -> Int {
        switch self {
        case .all: return station.totalBikes
        case .electrical: return station.electricalBikes
        case .parking: return station.docksAvailable
        }
    }

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

/// Shared by the map pins, the legend and the nearby-stations list so the colour coding stays
/// identical across all three.
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
        case .plenty: return String(localized: "Plenty", comment: "Map legend: lots of bikes or docks")
        case .few: return String(localized: "Few", comment: "Map legend: only a few bikes or docks")
        case .none: return String(localized: "None", comment: "Map legend: no bikes or docks")
        }
    }
}
