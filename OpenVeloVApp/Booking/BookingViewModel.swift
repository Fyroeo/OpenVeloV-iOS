import CoreLocation
import Foundation
import VLSKit

@MainActor
final class BookingViewModel: ObservableObject {
    @Published private(set) var activeBooking: Booking?

    private let authViewModel: AuthViewModel
    private let tripViewModel: TripViewModel
    private let settings: AppSettings
    private let locationService: RideLocationService
    private var isPreviewBooking = false
    private var bookingExpiryTask: Task<Void, Never>?

    init(
        authViewModel: AuthViewModel,
        tripViewModel: TripViewModel,
        settings: AppSettings,
        locationService: RideLocationService
    ) {
        self.authViewModel = authViewModel
        self.tripViewModel = tripViewModel
        self.settings = settings
        self.locationService = locationService
    }

    /// The server keeps reporting a hold as active even after a ride has consumed it, so
    /// `consumedBookingID` is excluded here to stop a stale refresh resurrecting it.
    func refreshActiveBooking() async {
        guard authViewModel.isAuthenticated, let accountId = authViewModel.accountId else {
            await setActiveBooking(nil)
            return
        }
        do {
            let bookings = try await authViewModel.client.bookings.bookings(accountId: accountId)
            await setActiveBooking(bookings.first { $0.endTime > Date() && $0.id != consumedBookingID })
        } catch {
            // A failed refresh is usually transient, so the last known booking state is kept.
        }
    }

    /// A real, billable action, so callers must confirm first; a preview booking only simulates it
    /// and never reaches the server.
    func unlockActiveBooking() async -> (success: Bool, message: String) {
        guard let booking = activeBooking else {
            return (false, String(localized: "No active booking."))
        }
        if isPreviewBooking {
            activeBooking = nil
            isPreviewBooking = false
            LiveActivityManager.endBookingActivity()
            return (true, String(localized: "Preview only — no real bike was unlocked."))
        }
        guard let accountId = authViewModel.accountId, let stationNumber = booking.stationNumber else {
            return (false, String(localized: "This booking is missing the details needed to unlock."))
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
                return (true, String(localized: "You have 60 seconds to take the bike out of the stand."))
            } else {
                return (false, String(localized: "Vélo'v turned down the unlock (\(response.transactionState.rawValue)). Try again, or pick another bike."))
            }
        } catch {
            return (false, UserFacingError.message(for: error, context: .unlock))
        }
    }

    func handleTripStarted() async {
        guard activeBooking != nil else { return }
        consumedBookingID = activeBooking?.id
        await setActiveBooking(nil)
    }

    func reset() {
        bookingExpiryTask?.cancel()
        bookingExpiryTask = nil
        LiveActivityManager.endBookingActivity()
        locationService.stopWatchingBooking()
        NotificationManager.cancelBookingArrival()
        activeBooking = nil
        isPreviewBooking = false
    }

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
                endBookingSideEffects()
            }
            return
        }
        let interval = booking.endTime.timeIntervalSinceNow
        guard interval > 0 else {
            activeBooking = nil
            if hadActiveBooking {
                endBookingSideEffects()
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
        if settings.isBookingArrivalAlertEnabled, let coordinate = display.coordinate {
            locationService.startWatchingBooking(
                coordinate: coordinate,
                stationName: display.stationName,
                bikeNumber: display.bikeNumber
            )
        }
        bookingExpiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            await self.refreshActiveBooking()
        }
    }

    private func endBookingSideEffects() {
        LiveActivityManager.endBookingActivity()
        NotificationManager.cancelBookingExpiry()
        NotificationManager.cancelBookingArrival()
        locationService.stopWatchingBooking()
    }

    /// A `Booking` carries only `stationNumber` and `bikeId`, so the station name, coordinate and
    /// bike number each need a separate best-effort lookup that is allowed to come back empty.
    private func resolveBookingDisplay(
        _ booking: Booking
    ) async -> (stationName: String, bikeNumber: Int, isElectric: Bool, coordinate: CLLocationCoordinate2D?) {
        var stationName = booking.stationNumber.map { String(localized: "Station \($0.identifierText)") } ?? String(localized: "Vélo'v station")
        var bikeNumber = 0
        var isElectric = false
        var coordinate: CLLocationCoordinate2D?
        if let stationNumber = booking.stationNumber {
            if let station = try? await authViewModel.client.stations.station(number: stationNumber) {
                stationName = station.name
                if let location = station.location {
                    coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                }
            }
            if let bikesAtStation = try? await authViewModel.client.bikes.bikes(atStationNumber: stationNumber),
               let bike = bikesAtStation.first(where: { $0.id == booking.bikeId }) {
                bikeNumber = bike.number
                isElectric = bike.type == .electrical
            }
        }
        return (stationName, bikeNumber, isElectric, coordinate)
    }

#if DEBUG
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
