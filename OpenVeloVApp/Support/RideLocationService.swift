import CoreLocation
import Foundation
import VLSKit

/// Location tracking that only runs while a ride or a hold is active.
@MainActor
final class RideLocationService: NSObject, ObservableObject {

    @Published private(set) var recordedPoints: [TripPoint] = []
    @Published private(set) var isTracking = false

    /// Thins the trace; a point every few metres would mean thousands per ride.
    private let minimumPointDistance: CLLocationDistance = 20

    private let arrivalRadius: CLLocationDistance = 100

    private let manager = CLLocationManager()
    private var isRecordingRide = false
    private var bookingTarget: (coordinate: CLLocationCoordinate2D, stationName: String, bikeNumber: Int)?
    private var hasAnnouncedArrival = false
    private var lastRecordedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .fitness
    }

    // MARK: - Ride recording

    func startRecordingRide() {
        guard !isRecordingRide else { return }
        isRecordingRide = true
        recordedPoints = []
        lastRecordedLocation = nil
        updateTracking()
    }

    /// Returns the recorded trace, or an empty array when fewer than two points survived the
    /// thinning and there is no route worth drawing.
    @discardableResult
    func stopRecordingRide() -> [TripPoint] {
        isRecordingRide = false
        let points = recordedPoints
        recordedPoints = []
        lastRecordedLocation = nil
        updateTracking()
        return points.count >= 2 ? points : []
    }

    // MARK: - Booking arrival

    func startWatchingBooking(coordinate: CLLocationCoordinate2D, stationName: String, bikeNumber: Int) {
        bookingTarget = (coordinate, stationName, bikeNumber)
        hasAnnouncedArrival = false
        updateTracking()
    }

    func stopWatchingBooking() {
        bookingTarget = nil
        hasAnnouncedArrival = false
        updateTracking()
    }

    func stopAll() {
        isRecordingRide = false
        bookingTarget = nil
        recordedPoints = []
        lastRecordedLocation = nil
        updateTracking()
    }

    // MARK: - Tracking lifecycle

    private func updateTracking() {
        let shouldTrack = isRecordingRide || bookingTarget != nil
        guard shouldTrack != isTracking else { return }
        isTracking = shouldTrack

        if shouldTrack {
            let status = manager.authorizationStatus
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                isTracking = false
                return
            }
            // Setting this without the authorization checked above, and the location background
            // mode in Info.plist, traps at runtime.
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false
        }
    }

    private func handle(_ location: CLLocation) {
        if isRecordingRide {
            record(location)
        }
        if let target = bookingTarget, !hasAnnouncedArrival {
            let distance = location.distance(from: CLLocation(latitude: target.coordinate.latitude, longitude: target.coordinate.longitude))
            if distance <= arrivalRadius {
                hasAnnouncedArrival = true
                NotificationManager.notifyBookingArrival(stationName: target.stationName, bikeNumber: target.bikeNumber)
            }
        }
    }

    private func record(_ location: CLLocation) {
        // A stationary phone drifts, filling the trace with noise at every red light.
        if let last = lastRecordedLocation, location.distance(from: last) < minimumPointDistance {
            return
        }
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy < 100 else { return }
        lastRecordedLocation = location
        recordedPoints.append(
            TripPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                elevation: location.altitude
            )
        )
    }
}

extension RideLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let received = locations
        Task { @MainActor in
            for location in received {
                self.handle(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: a gap in the trace; the arrival check retries on the next update.
    }
}
