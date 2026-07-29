import CoreLocation
import Foundation
import VLSKit

struct MapStation: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let capacity: Int?
    let mechanicalBikes: Int
    let electricalBikes: Int
    let docksAvailable: Int
    let isRenting: Bool
    let isReturning: Bool

    var totalBikes: Int { mechanicalBikes + electricalBikes }

    /// The GBFS id happens to be the station number the private API keys on, hence the conversion.
    var number: Int? { Int(id) }

    static func == (lhs: MapStation, rhs: MapStation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(information: GBFSStationInformation, status: GBFSStationStatus?) {
        id = information.id
        name = information.name.first(where: { $0.language.hasPrefix("fr") })?.text
            ?? information.name.first?.text
            ?? "Station \(information.id)"
        coordinate = CLLocationCoordinate2D(latitude: information.latitude, longitude: information.longitude)
        capacity = information.capacity

        guard let status else {
            mechanicalBikes = 0
            electricalBikes = 0
            docksAvailable = 0
            isRenting = false
            isReturning = false
            return
        }
        mechanicalBikes = status.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .mechanical })?.count ?? 0
        electricalBikes = status.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .electrical })?.count ?? 0
        docksAvailable = status.numDocksAvailable
        isRenting = status.isRenting
        isReturning = status.isReturning
    }

    /// Spelled out because the GBFS initializer above suppresses the synthesized memberwise one,
    /// which previews and tests still need.
    init(
        id: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        capacity: Int?,
        mechanicalBikes: Int,
        electricalBikes: Int,
        docksAvailable: Int,
        isRenting: Bool,
        isReturning: Bool
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.capacity = capacity
        self.mechanicalBikes = mechanicalBikes
        self.electricalBikes = electricalBikes
        self.docksAvailable = docksAvailable
        self.isRenting = isRenting
        self.isReturning = isReturning
    }
}

// MARK: - Distance

extension MapStation {
    func distance(from location: UserLocation?) -> CLLocationDistance? {
        location?.distance(to: coordinate)
    }

    static func distanceText(_ metres: CLLocationDistance) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    static func walkingMinutes(for metres: CLLocationDistance) -> Int {
        let metresPerMinute = 5_000.0 / 60.0
        return max(1, Int((metres / metresPerMinute).rounded(.up)))
    }

    /// Past this nobody walks, so `walkingTimeText` shows nothing rather than a silly figure.
    static let maximumWalkableDistance: CLLocationDistance = 5_000

    static func walkingTimeText(for metres: CLLocationDistance) -> String? {
        guard metres <= maximumWalkableDistance else { return nil }
        return String(localized: "~\(walkingMinutes(for: metres)) min")
    }
}
