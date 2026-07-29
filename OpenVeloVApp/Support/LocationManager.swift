import CoreLocation
import Foundation

struct UserLocation: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        clLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
}

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var userLocation: UserLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    @discardableResult
    func requestAuthorizationAwaitingDecision(timeout: TimeInterval = 30) async -> CLAuthorizationStatus {
        guard authorizationStatus == .notDetermined else { return authorizationStatus }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()

            // A prompt dismissed without an answer would otherwise await forever.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self else { return }
                self.finishAuthorizationRequest(with: self.authorizationStatus)
            }
        }
    }

    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    /// Resumes at most once; resuming a continuation twice traps.
    fileprivate func finishAuthorizationRequest(with status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func firstLocation(timeout: TimeInterval = 3) async -> UserLocation? {
        if let userLocation { return userLocation }
        guard isAuthorized else { return nil }
        startUpdating()

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let userLocation { return userLocation }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return userLocation
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdating()
            }
            if status != .notDetermined {
                self.finishAuthorizationRequest(with: status)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.userLocation = UserLocation(coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignored on purpose: location only centres the map, and stations list fine without it.
    }
}
