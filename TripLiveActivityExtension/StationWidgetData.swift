import CoreLocation
import Foundation
import VLSKit

struct StationSnapshot: Sendable, Hashable {
    let number: String
    let name: String
    let latitude: Double
    let longitude: Double
    let mechanicalBikes: Int
    let electricalBikes: Int
    let docksAvailable: Int
    let isRenting: Bool
    let isReturning: Bool

    var totalBikes: Int { mechanicalBikes + electricalBikes }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let placeholder = StationSnapshot(
        number: "3015",
        name: "SERVIENT / GARIBALDI",
        latitude: 45.7554,
        longitude: 4.8493,
        mechanicalBikes: 6,
        electricalBikes: 4,
        docksAvailable: 8,
        isRenting: true,
        isReturning: true
    )
}

enum StationWidgetData {
    private static let client = GBFSClient(contract: VLSEnvironment.lyon.contract, environment: .lyon)

    /// Skips the status feed, so every count comes back zero: this only feeds the widget's station
    /// picker, which needs names and coordinates.
    static func allStations() async throws -> [StationSnapshot] {
        let information = try await client.stationInformation().data.stations
        return information.map { station in
            StationSnapshot(
                number: station.id,
                name: station.name.first(where: { $0.language.hasPrefix("fr") })?.text
                    ?? station.name.first?.text
                    ?? "Station \(station.id)",
                latitude: station.latitude,
                longitude: station.longitude,
                mechanicalBikes: 0,
                electricalBikes: 0,
                docksAvailable: 0,
                isRenting: false,
                isReturning: false
            )
        }
    }

    static func liveStations() async throws -> [StationSnapshot] {
        async let informationFeed = client.stationInformation()
        async let statusFeed = client.stationStatus()

        let information = try await informationFeed.data.stations
        let statusByID = Dictionary(
            uniqueKeysWithValues: try await statusFeed.data.stations.map { ($0.id, $0) }
        )

        return information.map { station in
            let status = statusByID[station.id]
            return StationSnapshot(
                number: station.id,
                name: station.name.first(where: { $0.language.hasPrefix("fr") })?.text
                    ?? station.name.first?.text
                    ?? "Station \(station.id)",
                latitude: station.latitude,
                longitude: station.longitude,
                mechanicalBikes: status?.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .mechanical })?.count ?? 0,
                electricalBikes: status?.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .electrical })?.count ?? 0,
                docksAvailable: status?.numDocksAvailable ?? 0,
                isRenting: status?.isRenting ?? false,
                isReturning: status?.isReturning ?? false
            )
        }
    }

    static func station(number: String) async throws -> StationSnapshot? {
        try await liveStations().first { $0.number == number }
    }

    static func nearestStation(to coordinate: CLLocationCoordinate2D) async throws -> StationSnapshot? {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try await liveStations().min { lhs, rhs in
            here.distance(from: CLLocation(latitude: lhs.latitude, longitude: lhs.longitude))
                < here.distance(from: CLLocation(latitude: rhs.latitude, longitude: rhs.longitude))
        }
    }
}

/// A widget cannot prompt for location access, so this returns the last cached fix and only when
/// the host app has already been authorised.
enum WidgetLocation {
    static var current: CLLocationCoordinate2D? {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        return manager.location?.coordinate
    }
}
