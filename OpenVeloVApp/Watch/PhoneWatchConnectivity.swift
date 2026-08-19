import Foundation
import WatchConnectivity

/// The phone side of the watch link: pushes auth + booking state to the watch, and services the
/// watch's unlock requests by running `WatchUnlockService` on the phone's session.
///
/// Not main-actor isolated: `activate()` is called from `App.init` and the delegate callbacks
/// arrive on a background queue, so state is guarded by a lock instead.
final class PhoneWatchConnectivity: NSObject, @unchecked Sendable {
    static let shared = PhoneWatchConnectivity()

    private let lock = NSLock()
    private var authenticated = false
    private var bookingContext: [String: Any] = [:]

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func updateAuth(_ isAuthenticated: Bool) {
        lock.lock(); authenticated = isAuthenticated; lock.unlock()
        pushContext()
    }

    func updateBooking(bikeNumber: Int, stationName: String, endTime: Date) {
        lock.lock()
        bookingContext = [
            WatchLink.bookingBikeKey: bikeNumber,
            WatchLink.bookingStationKey: stationName,
            WatchLink.bookingEndKey: endTime.timeIntervalSince1970,
        ]
        lock.unlock()
        pushContext()
    }

    func clearBooking() {
        lock.lock(); bookingContext = [:]; lock.unlock()
        pushContext()
    }

    private func pushContext() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        lock.lock()
        var context: [String: Any] = [WatchLink.authenticatedKey: authenticated]
        context.merge(bookingContext) { $1 }
        lock.unlock()
        try? session.updateApplicationContext(context)
    }
}

extension PhoneWatchConnectivity: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        pushContext()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Pull out Sendable primitives before crossing into the task.
        let action = message[WatchLink.actionKey] as? String
        let stationNumber = message[WatchLink.stationNumberKey] as? Int
        let standNumber = message[WatchLink.standNumberKey] as? Int
        let bikeNumber = message[WatchLink.bikeNumberKey] as? Int
        Task {
            switch action {
            case WatchLink.listBikes where stationNumber != nil:
                let bikes = await WatchUnlockService.availableBikes(atStation: stationNumber!)
                let data = (try? JSONEncoder().encode(bikes)) ?? Data()
                replyHandler([WatchLink.bikesKey: data])
            case WatchLink.unlockBooking:
                let result = await WatchUnlockService.unlockActiveBooking()
                replyHandler([WatchLink.successKey: result.success, WatchLink.messageKey: result.message])
            case WatchLink.unlockChosenBike where stationNumber != nil && bikeNumber != nil:
                let result = await WatchUnlockService.unlockChosenBike(stationNumber: stationNumber!, standNumber: standNumber, bikeNumber: bikeNumber!)
                replyHandler([WatchLink.successKey: result.success, WatchLink.messageKey: result.message])
            default:
                replyHandler([WatchLink.successKey: false, WatchLink.messageKey: String(localized: "Unknown request.")])
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so the link survives the user switching paired watches.
        session.activate()
    }
}
