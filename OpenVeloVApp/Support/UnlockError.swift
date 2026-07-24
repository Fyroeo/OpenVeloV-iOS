import Foundation

enum UnlockError: LocalizedError {
    case notAuthenticated
    /// `debugInfo` holds temporary diagnostic detail: subscription count, type, lock state, and period-type breakdown.
    /// The alert shows this detail directly. There is no easy way to read this app's console output from a physical device.
    case noActiveSubscription(debugInfo: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Sign in to unlock a bike."
        case .noActiveSubscription(let debugInfo):
            return "No active Vélo'v subscription found on your account. (\(debugInfo))"
        }
    }
}
