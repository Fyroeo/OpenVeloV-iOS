import Foundation

enum UnlockError: LocalizedError {
    case notAuthenticated
    /// `debugInfo` lists the rejected subscriptions with their type, lock state, and validity
    /// periods, and the alert shows it verbatim because console output is unreadable on a device.
    case noActiveSubscription(debugInfo: String)
    case missingBikeDetails

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "Sign in to unlock a bike.")
        case .noActiveSubscription(let debugInfo):
            return String(localized: "No active Vélo'v subscription found on your account. (\(debugInfo))")
        case .missingBikeDetails:
            return String(localized: "This bike is missing the station or stand number needed to unlock it.")
        }
    }

    /// What `UserFacingError` shows a rider: the same failures without the diagnostic detail that
    /// `errorDescription` carries.
    var riderMessage: String {
        switch self {
        case .notAuthenticated:
            return String(localized: "Sign in to unlock a bike.")
        case .noActiveSubscription:
            return String(localized: "No active Vélo'v subscription found on your account.")
        case .missingBikeDetails:
            return String(localized: "Vélo'v didn't report where this bike is docked, so it can't be unlocked from here.")
        }
    }
}
