import Foundation
import UIKit
import VLSKit

/// Tracks the rider's active trip: starting, ending, and watching for a ride to start
/// after an unlock.
@MainActor
final class TripViewModel: ObservableObject {
    @Published private(set) var activeTrip: Trip?
    /// Set the instant a ride ends unrated. Cleared once rated or dismissed.
    @Published var tripToRate: Trip?

    private let authViewModel: AuthViewModel
    private var tripPollTask: Task<Void, Never>?
    private var rideStartWatchTask: Task<Void, Never>?
    private var rideStartBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Called once a new trip is confirmed to have started, so `BookingViewModel` can
    /// clear a booking that led to it.
    var onTripStarted: (() async -> Void)?

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    /// Detects when the rider docks the bike and ends the ride. `startTripPolling`
    /// calls this function periodically while a trip is active.
    func refreshActiveTrip() async {
        guard authViewModel.isAuthenticated, let accountId = authViewModel.accountId else {
            await setActiveTrip(nil)
            return
        }
        do {
            let trips = try await authViewModel.client.trips.ongoingTrips(accountId: accountId)
            await setActiveTrip(trips.first)
        } catch {
            // Likely transient. Keep the last known state.
        }
    }

    /// Call right after a successful `releaseBike`, not at ride start — those are 2
    /// different moments. Unlocking opens a ~60s window to pull the bike out, and
    /// `ongoingTrips` reports nothing until the rider does, so this polls for up to 100s
    /// in the background instead of assuming the trip starts at once.
    func watchForRideStart() {
        rideStartWatchTask?.cancel()
        endRideStartBackgroundTask()
        rideStartBackgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ride-start-watch") { [weak self] in
            self?.endRideStartBackgroundTask()
        }
        rideStartWatchTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<20 {
                if Task.isCancelled { break }
                await self.refreshActiveTrip()
                if self.activeTrip != nil { break }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            self.endRideStartBackgroundTask()
        }
    }

    /// Ends tracking and the Live Activity, for sign-out.
    func reset() {
        stopTripPolling()
        rideStartWatchTask?.cancel()
        rideStartWatchTask = nil
        endRideStartBackgroundTask()
        LiveActivityManager.endCurrent()
        activeTrip = nil
        tripToRate = nil
    }

    private func endRideStartBackgroundTask() {
        guard rideStartBackgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(rideStartBackgroundTaskID)
        rideStartBackgroundTaskID = .invalid
    }

    private func setActiveTrip(_ trip: Trip?) async {
        let previousTrip = activeTrip
        let hadActiveTrip = previousTrip != nil
        activeTrip = trip
        if let trip {
            if hadActiveTrip {
                LiveActivityManager.update(trip: trip)
            } else {
                LiveActivityManager.start(trip: trip)
                startTripPolling()
                await onTripStarted?()
            }
        } else if hadActiveTrip {
            LiveActivityManager.endCurrent()
            stopTripPolling()
            if let previousTrip {
                NotificationManager.notifyRideEnded(trip: previousTrip)
                if previousTrip.isRated != true {
                    tripToRate = previousTrip
                }
            }
        }
    }

    private func startTripPolling() {
        tripPollTask?.cancel()
        tripPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.refreshActiveTrip()
            }
        }
    }

    private func stopTripPolling() {
        tripPollTask?.cancel()
        tripPollTask = nil
    }

#if DEBUG
    /// Debug-only: previews the active-ride UI with a fake trip, bypassing the network.
    func togglePreviewRide() {
        if activeTrip != nil {
            activeTrip = nil
            LiveActivityManager.endCurrent()
            return
        }
        let started = Date(timeIntervalSinceNow: -12 * 60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let json = """
        { "bikeNumber": 25391, "bikeType": 1, "status": "STARTED",
          "startDateTime": "\(formatter.string(from: started))" }
        """
        guard let trip = try? JSONDecoder.vls.decode(Trip.self, from: Data(json.utf8)) else { return }
        // Set directly, not via `setActiveTrip`, so the trip poll does not clear it.
        activeTrip = trip
        LiveActivityManager.start(trip: trip)
    }
#endif
}
