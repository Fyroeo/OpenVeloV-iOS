import Foundation
import VLSKit

/// Tracks the rider's active booking hold: creating, unlocking, and expiry.
@MainActor
final class BookingViewModel: ObservableObject {
    @Published private(set) var activeBooking: Booking?

    private let authViewModel: AuthViewModel
    private let tripViewModel: TripViewModel
    private var isPreviewBooking = false
    private var bookingExpiryTask: Task<Void, Never>?

    init(authViewModel: AuthViewModel, tripViewModel: TripViewModel) {
        self.authViewModel = authViewModel
        self.tripViewModel = tripViewModel
    }

    /// Excludes `consumedBookingID`; see `clearActiveBookingAfterUnlock`; so a
    /// just-unlocked hold cannot reappear from a stale server refresh.
    func refreshActiveBooking() async {
        guard authViewModel.isAuthenticated, let accountId = authViewModel.accountId else {
            await setActiveBooking(nil)
            return
        }
        do {
            let bookings = try await authViewModel.client.bookings.bookings(accountId: accountId)
            await setActiveBooking(bookings.first { $0.endTime > Date() && $0.id != consumedBookingID })
        } catch {
            // Likely transient. Keep the last known state.
        }
    }

    /// Unlocks the currently booked bike. A real, billable action; callers must confirm
    /// first. A preview booking only simulates this and never reaches the server.
    func unlockActiveBooking() async -> (success: Bool, message: String) {
        guard let booking = activeBooking else {
            return (false, "No active booking.")
        }
        if isPreviewBooking {
            activeBooking = nil
            isPreviewBooking = false
            LiveActivityManager.endBookingActivity()
            return (true, "Preview only — no real bike was unlocked.")
        }
        guard let accountId = authViewModel.accountId, let stationNumber = booking.stationNumber else {
            return (false, "This booking is missing the details needed to unlock.")
        }
        do {
            let subscriptionId = try await authViewModel.resolveActiveSubscriptionId()
            let bikes = (try? await authViewModel.client.bikes.bikes(atStationNumber: stationNumber)) ?? []
            let bikeNumber = bikes.first { $0.id == booking.bikeId }?.number
            let request = ReleaseBikeRequest(
                stationNumber: stationNumber,
                standNumber: booking.standNumber.map(Int.init),
                bikeNumber: bikeNumber
            )
            let response = try await authViewModel.client.trips.releaseBike(accountId: accountId, subscriptionId: subscriptionId, request: request)
            if response.transactionState == .ok {
                // Booking clears only once a trip actually starts — see `handleTripStarted`.
                tripViewModel.watchForRideStart()
                return (true, "You have 60 seconds to take the bike out of the stand.")
            } else {
                return (false, "Unlock status: \(response.transactionState.rawValue)")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// Called once `TripViewModel` confirms a new trip has started, not right after
    /// `releaseBike` succeeds, since a successful unlock alone does not confirm the
    /// rider got the bike out.
    ///
    /// The booking API has no "this hold was consumed" signal: the server keeps
    /// reporting it as active until it expires. Clearing `activeBooking` in memory is
    /// not enough, since the next `refreshActiveBooking()` would re-adopt that stale
    /// record. `consumedBookingID` marks it to be ignored regardless of what the
    /// server still reports.
    func handleTripStarted() async {
        guard activeBooking != nil else { return }
        consumedBookingID = activeBooking?.id
        await setActiveBooking(nil)
    }

    /// Ends tracking and the Live Activity, for sign-out.
    func reset() {
        bookingExpiryTask?.cancel()
        bookingExpiryTask = nil
        LiveActivityManager.endBookingActivity()
        activeBooking = nil
        isPreviewBooking = false
    }

    /// Persisted, not just in-memory, since the same stale-refresh risk exists on the
    /// next app launch.
    private var consumedBookingID: UUID? {
        get { UserDefaults.standard.string(forKey: "consumedBookingID").flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: "consumedBookingID") }
    }

    private func setActiveBooking(_ booking: Booking?) async {
        let hadActiveBooking = activeBooking != nil
        activeBooking = booking
        bookingExpiryTask?.cancel()
        bookingExpiryTask = nil
        guard let booking else {
            if hadActiveBooking {
                LiveActivityManager.endBookingActivity()
                NotificationManager.cancelBookingExpiry()
            }
            return
        }
        let interval = booking.endTime.timeIntervalSinceNow
        guard interval > 0 else {
            activeBooking = nil
            if hadActiveBooking {
                LiveActivityManager.endBookingActivity()
                NotificationManager.cancelBookingExpiry()
            }
            return
        }
        let display = await resolveBookingDisplay(booking)
        let standNumber = booking.standNumber.map(Int.init)
        if hadActiveBooking {
            LiveActivityManager.updateBooking(endDate: booking.endTime, bikeNumber: display.bikeNumber, stationName: display.stationName, standNumber: standNumber, isElectric: display.isElectric)
        } else {
            LiveActivityManager.startBooking(endDate: booking.endTime, bikeNumber: display.bikeNumber, stationName: display.stationName, standNumber: standNumber, isElectric: display.isElectric)
        }
        NotificationManager.scheduleBookingExpiry(endDate: booking.endTime, bikeNumber: display.bikeNumber, stationName: display.stationName)
        bookingExpiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            await self.refreshActiveBooking()
        }
    }

    /// A booking has only `stationNumber`/`bikeId`; resolves the display name and bike
    /// number from those, best-effort.
    private func resolveBookingDisplay(_ booking: Booking) async -> (stationName: String, bikeNumber: Int, isElectric: Bool) {
        var stationName = booking.stationNumber.map { "Station \($0)" } ?? "Vélo'v station"
        var bikeNumber = 0
        var isElectric = false
        if let stationNumber = booking.stationNumber {
            if let station = try? await authViewModel.client.stations.station(number: stationNumber) {
                stationName = station.name
            }
            if let bikesAtStation = try? await authViewModel.client.bikes.bikes(atStationNumber: stationNumber),
               let bike = bikesAtStation.first(where: { $0.id == booking.bikeId }) {
                bikeNumber = bike.number
                isElectric = bike.type == .electrical
            }
        }
        return (stationName, bikeNumber, isElectric)
    }

#if DEBUG
    /// Debug-only: previews the booking-hold UI with a fake booking, bypassing the network.
    func togglePreviewBooking() {
        if activeBooking != nil {
            activeBooking = nil
            isPreviewBooking = false
            LiveActivityManager.endBookingActivity()
            return
        }
        let end = Date(timeIntervalSinceNow: 15 * 60)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let json = """
        { "id": "00000000-0000-0000-0000-000000000001",
          "contractName": "lyon",
          "accountId": "00000000-0000-0000-0000-000000000002",
          "subscriptionId": "00000000-0000-0000-0000-000000000003",
          "bikeId": "00000000-0000-0000-0000-000000000004",
          "stationNumber": 3015, "standNumber": 12,
          "endTime": "\(formatter.string(from: end))" }
        """
        guard let booking = try? JSONDecoder.vls.decode(Booking.self, from: Data(json.utf8)) else { return }
        activeBooking = booking
        isPreviewBooking = true
        LiveActivityManager.startBooking(endDate: booking.endTime, bikeNumber: 25391, stationName: "SERVIENT / GARIBALDI", standNumber: 12, isElectric: true)
    }
#endif
}
