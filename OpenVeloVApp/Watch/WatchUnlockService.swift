import Foundation
import VLSKit

extension Notification.Name {
    /// Posted after a watch-triggered unlock succeeds, so a live `TripViewModel` can start
    /// watching for the ride and bring up the Live Activity without waiting for the next foreground.
    static let watchDidUnlock = Notification.Name("net.socialeo.openvelov.watchDidUnlock")
}

/// Performs a bike unlock on behalf of the watch, using the phone's shared authenticated session.
/// Stateless and UI-free so it also runs when iOS launches the app in the background to service a
/// WatchConnectivity message.
enum WatchUnlockService {

    /// Unlocks the account's currently held booking, mirroring the phone's booking banner.
    static func unlockActiveBooking() async -> (success: Bool, message: String) {
        let client = AppClient.shared
        guard await client.isAuthenticated else { return (false, notSignedIn) }
        do {
            let accountId = try await resolveAccountId(client)
            let bookings = try await client.bookings.bookings(accountId: accountId)
            guard let booking = bookings.first(where: { $0.endTime > Date() }),
                  let stationNumber = booking.stationNumber else {
                return (false, String(localized: "No active booking to unlock."))
            }
            let subscriptionId = try await resolveSubscriptionId(client, accountId: accountId)
            let bikes = (try? await client.bikes.bikes(atStationNumber: stationNumber)) ?? []
            let bikeNumber = bikes.first { $0.id == booking.bikeId }?.number
            let request = ReleaseBikeRequest(
                stationNumber: stationNumber,
                standNumber: booking.standNumber.map(Int.init),
                bikeNumber: bikeNumber
            )
            return try await release(client, accountId: accountId, subscriptionId: subscriptionId, request: request)
        } catch {
            return (false, UserFacingError.message(for: error, context: .unlock))
        }
    }

    /// The available bikes at a station, so the rider can pick their own on the watch. Uses the same
    /// anonymous per-bike source the phone's station sheet uses (no account token needed, so it
    /// still works when iOS wakes the phone in the background). Empty if the lookup fails.
    static func availableBikes(atStation stationNumber: Int) async -> [WatchBike] {
        let client = BikeDetailClient(environment: AppSecrets.environment)
        guard let bikes = try? await client.bikes(atStationNumber: stationNumber) else { return [] }
        return bikes
            .filter { $0.status == .available }
            .sorted { ($0.standNumber ?? .max) < ($1.standNumber ?? .max) }
            .map { WatchBike(number: $0.number, stand: $0.standNumber, isElectric: $0.type == .electrical, battery: $0.battery?.percentage) }
    }

    /// Unlocks the specific bike the rider chose on the watch.
    static func unlockChosenBike(stationNumber: Int, standNumber: Int?, bikeNumber: Int) async -> (success: Bool, message: String) {
        let client = AppClient.shared
        guard await client.isAuthenticated else { return (false, notSignedIn) }
        do {
            let accountId = try await resolveAccountId(client)
            let subscriptionId = try await resolveSubscriptionId(client, accountId: accountId)
            let request = ReleaseBikeRequest(
                stationNumber: stationNumber,
                standNumber: standNumber,
                bikeNumber: bikeNumber
            )
            return try await release(client, accountId: accountId, subscriptionId: subscriptionId, request: request)
        } catch {
            return (false, UserFacingError.message(for: error, context: .unlock))
        }
    }

    // MARK: - Helpers

    private static var notSignedIn: String {
        String(localized: "Sign in on your iPhone to unlock.")
    }

    private static func release(
        _ client: VLSClient,
        accountId: UUID,
        subscriptionId: UUID,
        request: ReleaseBikeRequest
    ) async throws -> (success: Bool, message: String) {
        let response = try await client.trips.releaseBike(accountId: accountId, subscriptionId: subscriptionId, request: request)
        if response.transactionState == .ok {
            await MainActor.run { NotificationCenter.default.post(name: .watchDidUnlock, object: nil) }
            return (true, unlockedMessage(bikeNumber: request.bikeNumber, standNumber: request.standNumber))
        }
        return (false, String(localized: "Vélo'v turned down the unlock (\(response.transactionState.rawValue)). Try again."))
    }

    /// Tells the rider exactly which stand/bike opened, so they know where to go — the stand number
    /// is the physical locator at the station.
    private static func unlockedMessage(bikeNumber: Int?, standNumber: Int?) -> String {
        switch (bikeNumber, standNumber) {
        case let (bike?, stand?):
            return String(localized: "Take bike #\(bike.identifierText) from stand \(stand) — 60 seconds.")
        case let (nil, stand?):
            return String(localized: "Take the bike from stand \(stand) — 60 seconds.")
        case let (bike?, nil):
            return String(localized: "Take bike #\(bike.identifierText) — 60 seconds.")
        default:
            return String(localized: "Unlocked — take the bike out within 60 seconds.")
        }
    }

    private static func resolveAccountId(_ client: VLSClient) async throws -> UUID {
        guard let email = await client.auth.currentEmail else { throw UnlockError.notAuthenticated }
        return try await client.account.accountId(email: email)
    }

    private static func resolveSubscriptionId(_ client: VLSClient, accountId: UUID) async throws -> UUID {
        let now = Date()
        let subscriptions = try await client.subscriptions.subscriptions(accountId: accountId)
        guard let usable = subscriptions.first(where: { subscription in
            !subscription.isLocked && subscription.periods.contains { $0.validityStart <= now && now <= $0.validityEnd }
        }) else {
            throw UnlockError.noActiveSubscription(debugInfo: "\(subscriptions.count) subscriptions")
        }
        return usable.id
    }
}
