import Foundation
import UIKit
import VLSKit

@MainActor
final class TripViewModel: ObservableObject {
    @Published private(set) var activeTrip: Trip?
    @Published var tripToRate: Trip?
    @Published private(set) var didUploadRouteForLastTrip = false

    private let authViewModel: AuthViewModel
    private let settings: AppSettings
    private let locationService: RideLocationService
    private var tripPollTask: Task<Void, Never>?
    private var rideStartWatchTask: Task<Void, Never>?
    private var rideStartBackgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    /// Fired only on the transition into a ride, not on every poll that still sees one.
    var onTripStarted: (() async -> Void)?

    init(authViewModel: AuthViewModel, settings: AppSettings, locationService: RideLocationService) {
        self.authViewModel = authViewModel
        self.settings = settings
        self.locationService = locationService
    }

    func refreshActiveTrip() async {
        guard authViewModel.isAuthenticated, let accountId = authViewModel.accountId else {
            await setActiveTrip(nil)
            return
        }
        do {
            let trips = try await authViewModel.client.trips.ongoingTrips(accountId: accountId)
            await setActiveTrip(trips.first)
        } catch {
            // Keep the last known trip: treating a failed request as "no trip" would end the Live
            // Activity and prompt for a rating mid-ride.
        }
    }

    /// Call right after a successful `releaseBike`: the server only opens the trip once the rider
    /// actually pulls the bike out, so poll for up to 100 seconds waiting for it to appear.
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

    func reset() {
        stopTripPolling()
        rideStartWatchTask?.cancel()
        rideStartWatchTask = nil
        endRideStartBackgroundTask()
        LiveActivityManager.endCurrent()
        NotificationManager.cancelRideEndingSoon()
        locationService.stopRecordingRide()
        activeTrip = nil
        tripToRate = nil
    }

    func acknowledgeRouteUpload() {
        didUploadRouteForLastTrip = false
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
                beginRideSideEffects(for: trip)
                await onTripStarted?()
            }
        } else if hadActiveTrip {
            LiveActivityManager.endCurrent()
            stopTripPolling()
            NotificationManager.cancelRideEndingSoon()
            if let previousTrip {
                NotificationManager.notifyRideEnded(trip: previousTrip)
                await finishRouteRecording(for: previousTrip)
                if previousTrip.isRated != true {
                    tripToRate = previousTrip
                }
            }
        }
    }

    /// Called once, when the ride is first seen, so the ten-second poll does not reschedule these.
    private func beginRideSideEffects(for trip: Trip) {
        if settings.isRideEndingAlertEnabled {
            NotificationManager.scheduleRideEndingSoon(
                startDate: trip.startDateTime ?? Date(),
                freeMinutes: settings.freeRideMinutes,
                leadMinutes: settings.rideEndingLeadMinutes,
                bikeNumber: trip.bikeNumber
            )
        }
        if settings.isRouteRecordingEnabled {
            locationService.startRecordingRide()
        }
    }

    private func finishRouteRecording(for trip: Trip) async {
        let points = locationService.stopRecordingRide()
        guard !points.isEmpty,
              let accountId = authViewModel.accountId,
              let tripId = trip.id else { return }
        do {
            try await authViewModel.client.trips.uploadRoute(accountId: accountId, tripId: tripId, points: points)
            didUploadRouteForLastTrip = true
        } catch {
#if DEBUG
            print("[OpenVeloV] route upload failed: \(error.localizedDescription)")
#endif
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
        // Set directly rather than via `setActiveTrip`, which would start the poll and immediately
        // clear this fake trip.
        activeTrip = trip
        LiveActivityManager.start(trip: trip)
    }
#endif
}
