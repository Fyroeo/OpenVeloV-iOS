import Foundation
import WatchConnectivity

/// The watch side of the link: mirrors the phone's auth + booking state and forwards unlock
/// requests to the phone, which holds the account session and performs the unlock.
@MainActor
final class WatchConnectivityClient: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isReachable = false
    @Published private(set) var bookingBikeNumber: Int?
    @Published private(set) var bookingStationName: String?
    @Published private(set) var bookingEnd: Date?

    var hasBooking: Bool { bookingStationName != nil }

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func unlockBooking() async -> (success: Bool, message: String) {
        await send([WatchLink.actionKey: WatchLink.unlockBooking])
    }

    func unlock(_ bike: WatchBike, atStation stationNumber: Int) async -> (success: Bool, message: String) {
        var message: [String: Any] = [
            WatchLink.actionKey: WatchLink.unlockChosenBike,
            WatchLink.stationNumberKey: stationNumber,
            WatchLink.bikeNumberKey: bike.number,
        ]
        if let stand = bike.stand { message[WatchLink.standNumberKey] = stand }
        return await send(message)
    }

    /// Asks the phone for the pickable bikes at a station. Returns nil if unreachable so the UI can
    /// tell the rider to open the phone app.
    func bikes(atStation stationNumber: Int) async -> [WatchBike]? {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return nil }
        return await withCheckedContinuation { continuation in
            var didResume = false
            session.sendMessage([WatchLink.actionKey: WatchLink.listBikes, WatchLink.stationNumberKey: stationNumber], replyHandler: { reply in
                guard !didResume else { return }
                didResume = true
                let data = reply[WatchLink.bikesKey] as? Data ?? Data()
                let bikes = (try? JSONDecoder().decode([WatchBike].self, from: data)) ?? []
                continuation.resume(returning: bikes)
            }, errorHandler: { _ in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: [])
            })
        }
    }

    private func send(_ message: [String: Any]) async -> (success: Bool, message: String) {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            return (false, String(localized: "Open OpenVeloV on your iPhone, then try again."))
        }
        return await withCheckedContinuation { continuation in
            var didResume = false
            session.sendMessage(message, replyHandler: { reply in
                guard !didResume else { return }
                didResume = true
                let success = reply[WatchLink.successKey] as? Bool ?? false
                let text = reply[WatchLink.messageKey] as? String ?? ""
                continuation.resume(returning: (success, text))
            }, errorHandler: { error in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: (false, error.localizedDescription))
            })
        }
    }

    private func apply(authenticated: Bool, bike: Int?, station: String?, end: Double?) {
        isAuthenticated = authenticated
        bookingBikeNumber = bike
        bookingStationName = station
        bookingEnd = end.map { Date(timeIntervalSince1970: $0) }
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        let auth = context[WatchLink.authenticatedKey] as? Bool ?? false
        let bike = context[WatchLink.bookingBikeKey] as? Int
        let station = context[WatchLink.bookingStationKey] as? String
        let end = context[WatchLink.bookingEndKey] as? Double
        Task { @MainActor in
            self.isReachable = reachable
            if !context.isEmpty { self.apply(authenticated: auth, bike: bike, station: station, end: end) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let auth = applicationContext[WatchLink.authenticatedKey] as? Bool ?? false
        let bike = applicationContext[WatchLink.bookingBikeKey] as? Int
        let station = applicationContext[WatchLink.bookingStationKey] as? String
        let end = applicationContext[WatchLink.bookingEndKey] as? Double
        Task { @MainActor in self.apply(authenticated: auth, bike: bike, station: station, end: end) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
