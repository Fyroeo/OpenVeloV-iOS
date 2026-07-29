import AppIntents
import CoreLocation
import Foundation
import VLSKit

struct NearestBikesIntent: AppIntent {
    static var title: LocalizedStringResource { "Find bikes near me" }
    static var description: IntentDescription {
        IntentDescription("Tells you how many Vélo'v bikes are at the closest station.")
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await StationLookup.answer(for: .bikes)
    }
}

struct NearestDockIntent: AppIntent {
    static var title: LocalizedStringResource { "Find a Vélo'v dock" }
    static var description: IntentDescription {
        IntentDescription("Tells you where the closest free Vélo'v dock is.")
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await StationLookup.answer(for: .docks)
    }
}

struct OpenStationMapIntent: AppIntent {
    static var title: LocalizedStringResource { "Open the Vélo'v map" }
    static var description: IntentDescription {
        IntentDescription("Opens OpenVeloV on the live station map.")
    }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

enum StationLookup {
    enum Kind {
        case bikes
        case docks
    }

    @MainActor
    static func answer(for kind: Kind) async throws -> some IntentResult & ProvidesDialog {
        guard let coordinate = await IntentLocation.current() else {
            return .result(dialog: "I need location access to find the nearest station. You can turn it on in Settings.")
        }

        let client = GBFSClient(contract: VLSEnvironment.lyon.contract, environment: .lyon)
        async let informationFeed = client.stationInformation()
        async let statusFeed = client.stationStatus()
        let information = try await informationFeed.data.stations
        let statusByID = Dictionary(uniqueKeysWithValues: try await statusFeed.data.stations.map { ($0.id, $0) })

        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let candidates = information.compactMap { station -> (name: String, count: Int, distance: Double)? in
            guard let status = statusByID[station.id] else { return nil }
            let count: Int
            switch kind {
            case .bikes:
                guard status.isRenting else { return nil }
                count = status.vehicleTypesAvailable.reduce(0) { $0 + $1.count }
            case .docks:
                guard status.isReturning else { return nil }
                count = status.numDocksAvailable
            }
            guard count > 0 else { return nil }
            let name = station.name.first(where: { $0.language.hasPrefix("fr") })?.text
                ?? station.name.first?.text
                ?? "Station \(station.id)"
            let distance = here.distance(from: CLLocation(latitude: station.latitude, longitude: station.longitude))
            return (name, count, distance)
        }

        guard let nearest = candidates.min(by: { $0.distance < $1.distance }) else {
            return .result(dialog: kind == .bikes
                           ? "I couldn't find a station with a bike near you."
                           : "I couldn't find a station with a free dock near you.")
        }

        let distanceText = MapStation.distanceText(nearest.distance)
        let subject = kind == .bikes
            ? String(localized: "^[\(nearest.count) bike](inflect: true)")
            : String(localized: "^[\(nearest.count) free dock](inflect: true)")

        return .result(dialog: "\(nearest.name) has \(subject), about \(distanceText) away.")
    }
}

private final class IntentLocation: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    static func current() async -> CLLocationCoordinate2D? {
        let helper = IntentLocation()
        return await helper.request()
    }

    private func request() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        if let cached = manager.location, Date().timeIntervalSince(cached.timestamp) < 120 {
            return cached.coordinate
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                self?.finish(with: nil)
            }
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }
}

/// Every phrase has to embed `.applicationName`; AppShortcuts rejects any phrase without it.
struct VeloVShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NearestBikesIntent(),
            phrases: [
                "Find bikes near me with \(.applicationName)",
                "Is there a Vélo'v near me with \(.applicationName)",
                "\(.applicationName) nearest bike"
            ],
            shortTitle: "Nearest bikes",
            systemImageName: "bicycle"
        )
        AppShortcut(
            intent: NearestDockIntent(),
            phrases: [
                "Find a dock with \(.applicationName)",
                "Where can I park my Vélo'v with \(.applicationName)",
                "\(.applicationName) nearest dock"
            ],
            shortTitle: "Nearest dock",
            systemImageName: "parkingsign"
        )
        AppShortcut(
            intent: OpenStationMapIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show the \(.applicationName) map"
            ],
            shortTitle: "Open map",
            systemImageName: "map"
        )
    }
}
