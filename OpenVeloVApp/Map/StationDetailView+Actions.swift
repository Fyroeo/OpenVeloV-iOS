import SwiftUI
import UIKit
import VLSKit

extension StationDetailView {
    // MARK: - Bike ordering

    var sortedBikes: [Bike] {
        let bookedId = bookingVM.activeBooking?.bikeId
        return bikes.sorted { lhs, rhs in
            if let bookedId {
                if lhs.id == bookedId && rhs.id != bookedId { return true }
                if rhs.id == bookedId && lhs.id != bookedId { return false }
            }
            switch bikeSort {
            case .stand:
                return (lhs.standNumber ?? .max) < (rhs.standNumber ?? .max)
            case .battery:
                let lhsBattery = lhs.battery?.percentage ?? -1
                let rhsBattery = rhs.battery?.percentage ?? -1
                if lhsBattery != rhsBattery { return lhsBattery > rhsBattery }
                return (lhs.standNumber ?? .max) < (rhs.standNumber ?? .max)
            case .rating:
                let lhsRating = lhs.rating.value ?? -1
                let rhsRating = rhs.rating.value ?? -1
                if lhsRating != rhsRating { return lhsRating > rhsRating }
                return (lhs.standNumber ?? .max) < (rhs.standNumber ?? .max)
            }
        }
    }

    var recommendedBikeID: UUID? {
        let candidates = bikes.filter { $0.status == .available }
        guard candidates.count > 1 else { return nil }
        return candidates.max { lhs, rhs in
            let lhsRating = lhs.rating.value ?? 50
            let rhsRating = rhs.rating.value ?? 50
            if lhsRating != rhsRating { return lhsRating < rhsRating }
            return (lhs.battery?.percentage ?? 0) < (rhs.battery?.percentage ?? 0)
        }?.id
    }

    // MARK: - Actions

    func loadBikes() async {
        guard ContentView.isBikeDetailConfigured else { return }
        guard let stationNumber = station.number else {
            bikesErrorMessage = String(localized: "This station's number couldn't be read.")
            return
        }
        let isInitialLoad = bikes.isEmpty
        if isInitialLoad { isLoadingBikes = true }
        defer { if isInitialLoad { isLoadingBikes = false } }
        do {
            bikes = try await bikeDetailClient.bikes(atStationNumber: stationNumber)
            bikesErrorMessage = nil
        } catch {
            bikesErrorMessage = UserFacingError.message(for: error, context: .bikes)
        }
    }

    /// A bike the rider can act on: available to rent, or the one they've booked (which
    /// reports `.reserved`, not `.available`).
    func canUnlock(_ bike: Bike) -> Bool {
        bike.status == .available || bike.id == bookingVM.activeBooking?.bikeId
    }

    func handleTap(on bike: Bike) {
        guard canUnlock(bike) else { return }
        guard authVM.isAuthenticated else {
            showSignInRequired = true
            return
        }
        actionResult = nil
        bikeToConfirm = bike
    }

    /// The swipe path: skip the chooser and start the unlock immediately, presenting the
    /// action sheet already in its progress state so it acts as a result HUD.
    func directUnlock(_ bike: Bike) {
        guard canUnlock(bike) else { return }
        guard authVM.isAuthenticated else {
            showSignInRequired = true
            return
        }
        actionResult = nil
        isUnlocking = true
        bikeToConfirm = bike
        Task { await unlock(bike) }
    }

    func unlock(_ bike: Bike) async {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            guard let accountId = authVM.accountId else { throw UnlockError.notAuthenticated }
            let subscriptionId = try await authVM.resolveActiveSubscriptionId()
            let request = ReleaseBikeRequest(
                stationNumber: bike.stationNumber,
                standNumber: bike.standNumber,
                bikeNumber: bike.number
            )
            let response = try await authVM.client.trips.releaseBike(accountId: accountId, subscriptionId: subscriptionId, request: request)
            if response.transactionState == .ok {
                // A successful unlock only opens the stand for about 60 seconds; it is not the ride
                // start, so `watchForRideStart()` below has to poll for the trip separately.
                actionResult = BikeActionSheet.ActionResult(
                    succeeded: true,
                    title: String(localized: "Bike Unlocked"),
                    message: String(localized: "You have 60 seconds to take bike #\(bike.number.identifierText) out of the stand.")
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await loadBikes()
                tripVM.watchForRideStart()
            } else {
                actionResult = BikeActionSheet.ActionResult(
                    succeeded: false,
                    title: String(localized: "Unlock Failed"),
                    message: String(localized: "Vélo'v turned down the unlock (\(response.transactionState.rawValue)). Try again, or pick another bike.")
                )
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            actionResult = BikeActionSheet.ActionResult(
                succeeded: false,
                title: String(localized: "Unlock Failed"),
                message: UserFacingError.message(for: error, context: .unlock)
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func book(_ bike: Bike) async {
        isBooking = true
        defer { isBooking = false }
        do {
            guard let accountId = authVM.accountId else { throw UnlockError.notAuthenticated }
            guard let stationNumber = bike.stationNumber, let standNumber = bike.standNumber else {
                throw UnlockError.missingBikeDetails
            }
            let subscriptionId = try await authVM.resolveActiveSubscriptionId()
            let station = try await authVM.client.stations.station(number: stationNumber)
            let request = CreateBooking(
                stationId: station.id,
                stationNumber: stationNumber,
                standNumber: Int16(clamping: standNumber),
                subscriptionId: subscriptionId,
                bikeId: bike.id
            )
            _ = try await authVM.client.bookings.createBooking(accountId: accountId, booking: request)
            actionResult = BikeActionSheet.ActionResult(succeeded: true, title: String(localized: "Bike Booked"), message: String(localized: "Bike #\(bike.number.identifierText) is held for you — walk over and unlock it before the booking expires."))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await bookingVM.refreshActiveBooking()
        } catch {
            actionResult = BikeActionSheet.ActionResult(
                succeeded: false,
                title: String(localized: "Booking Failed"),
                message: UserFacingError.message(for: error, context: .booking)
            )
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
