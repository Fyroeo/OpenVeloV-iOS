import Foundation

/// Keys and payloads shared by the phone and the watch for their WatchConnectivity messages and
/// application context. Kept in one file compiled into both targets so the two sides can't drift.
enum WatchLink {
    // Message: watch → phone request
    static let actionKey = "action"
    static let unlockBooking = "unlockBooking"
    static let listBikes = "listBikes"
    static let unlockChosenBike = "unlockChosenBike"
    static let stationNumberKey = "station"
    static let standNumberKey = "stand"
    static let bikeNumberKey = "bike"

    // Reply: phone → watch
    static let successKey = "success"
    static let messageKey = "message"
    static let bikesKey = "bikes" // JSON-encoded [WatchBike]

    // Application context: phone → watch (latest state, coalesced)
    static let authenticatedKey = "authenticated"
    static let bookingBikeKey = "bookingBike"
    static let bookingStationKey = "bookingStation"
    static let bookingEndKey = "bookingEnd"
}

/// One selectable bike at a station, sent from the phone (which has the per-bike detail) to the
/// watch so the rider can pick their own bike rather than accept an automatic choice.
struct WatchBike: Codable, Identifiable, Sendable, Hashable {
    let number: Int
    let stand: Int?
    let isElectric: Bool
    let battery: Int?

    var id: Int { number }
}
