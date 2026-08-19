import CoreLocation
import Foundation
import VLSKit

/// A lightweight station snapshot for the watch app and its complication. Built from the public
/// GBFS feed, so it needs no account and no API key.
struct WatchStation: Identifiable, Sendable, Hashable {
    let number: String
    let name: String
    let latitude: Double
    let longitude: Double
    let mechanical: Int
    let electric: Int
    let docks: Int
    let isRenting: Bool
    let isReturning: Bool

    var id: String { number }
    var totalBikes: Int { mechanical + electric }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from location: CLLocation) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: latitude, longitude: longitude))
    }

    static let placeholder = WatchStation(
        number: "3015", name: "Servient / Garibaldi",
        latitude: 45.7554, longitude: 4.8493,
        mechanical: 6, electric: 4, docks: 8, isRenting: true, isReturning: true
    )
}

enum WatchStationData {
    private static let client = GBFSClient(environment: .lyon)

    static func liveStations() async throws -> [WatchStation] {
        async let informationFeed = client.stationInformation()
        async let statusFeed = client.stationStatus()

        let information = try await informationFeed.data.stations
        let statusByID = Dictionary(
            uniqueKeysWithValues: try await statusFeed.data.stations.map { ($0.id, $0) }
        )

        return information.map { station in
            let status = statusByID[station.id]
            return WatchStation(
                number: station.id,
                name: station.name.first(where: { $0.language.hasPrefix("fr") })?.text
                    ?? station.name.first?.text
                    ?? "Station \(station.id)",
                latitude: station.latitude,
                longitude: station.longitude,
                mechanical: status?.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .mechanical })?.count ?? 0,
                electric: status?.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .electrical })?.count ?? 0,
                docks: status?.numDocksAvailable ?? 0,
                isRenting: status?.isRenting ?? false,
                isReturning: status?.isReturning ?? false
            )
        }
    }

    /// Nearest stations to a coordinate, closest first.
    static func nearby(to coordinate: CLLocationCoordinate2D, limit: Int = 8) async throws -> [WatchStation] {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let stations = try await liveStations()
        return Array(stations.sorted { $0.distance(from: here) < $1.distance(from: here) }.prefix(limit))
    }
}

/// A widget cannot prompt for location, so this returns the last cached fix and only when the
/// host has already been authorised.
enum WatchPassiveLocation {
    static var current: CLLocationCoordinate2D? {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        return manager.location?.coordinate
    }
}

/// Metres formatted for a tiny screen: "120 m" / "1.4 km".
func watchDistanceText(_ metres: CLLocationDistance) -> String {
    if metres >= 1000 {
        return (metres / 1000).formatted(.number.precision(.fractionLength(1))) + " km"
    }
    return "\(Int(metres)) m"
}
