import CoreLocation
import Foundation

@MainActor
final class WatchStationStore: ObservableObject {
    @Published private(set) var nearby: [WatchStation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private var lastLoadCoordinate: CLLocationCoordinate2D?

    /// Nearest station that currently has a bike to take.
    var nearestBike: (station: WatchStation, distance: CLLocationDistance)? {
        best { $0.isRenting && $0.totalBikes > 0 }
    }

    /// Nearest station that currently has a free dock.
    var nearestDock: (station: WatchStation, distance: CLLocationDistance)? {
        best { $0.isReturning && $0.docks > 0 }
    }

    private func best(where predicate: (WatchStation) -> Bool) -> (WatchStation, CLLocationDistance)? {
        guard let origin = lastLoadCoordinate else { return nearby.first(where: predicate).map { ($0, 0) } }
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return nearby.filter(predicate)
            .map { ($0, $0.distance(from: here)) }
            .min { $0.1 < $1.1 }
    }

    func distance(to station: WatchStation) -> CLLocationDistance? {
        guard let origin = lastLoadCoordinate else { return nil }
        return station.distance(from: CLLocation(latitude: origin.latitude, longitude: origin.longitude))
    }

    func load(near coordinate: CLLocationCoordinate2D?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let coordinate {
                lastLoadCoordinate = coordinate
                nearby = try await WatchStationData.nearby(to: coordinate, limit: 10)
            } else {
                lastLoadCoordinate = nil
                nearby = try await WatchStationData.liveStations()
            }
            errorMessage = nil
            lastUpdated = Date()
        } catch {
            errorMessage = String(localized: "Couldn't load stations.")
        }
    }
}
