import Foundation
import VLSKit

enum UserFacingError {

    /// What the app was doing when the error surfaced.
    enum Context {
        case stations
        case bikes
        case unlock
        case booking
        case account
        case trips
        case subscription
        case generic

        var fallback: String {
            switch self {
            case .stations: return String(localized: "Couldn't load stations. Try again in a moment.")
            case .bikes: return String(localized: "Couldn't load the bikes at this station.")
            case .unlock: return String(localized: "Couldn't unlock this bike. Try again in a moment.")
            case .booking: return String(localized: "Couldn't hold this bike. Try again in a moment.")
            case .account: return String(localized: "Couldn't load your account.")
            case .trips: return String(localized: "Couldn't load your rides.")
            case .subscription: return String(localized: "Couldn't load your subscription.")
            case .generic: return String(localized: "Something went wrong. Try again in a moment.")
            }
        }

        var notFound: String {
            switch self {
            case .bikes: return String(localized: "This station isn't reporting its bikes right now.")
            case .trips: return String(localized: "This ride is no longer available.")
            case .subscription: return String(localized: "No subscription found on this account.")
            default: return String(localized: "That isn't available right now.")
            }
        }

        var notPermitted: String {
            switch self {
            case .bikes: return String(localized: "Vélo'v won't share per-bike detail with this account.")
            case .subscription: return String(localized: "Vélo'v won't share this subscription's details with this account.")
            case .account: return String(localized: "Vélo'v won't share this part of your account with the app.")
            default: return String(localized: "Vélo'v doesn't allow this app to do that.")
            }
        }
    }

    static func message(for error: Error, context: Context = .generic) -> String {
        log(error, context: context)

        if let unlockError = error as? UnlockError {
            return unlockError.riderMessage
        }
        if let vlsError = error as? VLSError {
            return message(for: vlsError, context: context)
        }
        if let urlError = error as? URLError {
            return message(for: urlError, context: context)
        }
        return context.fallback
    }

    private static func message(for error: VLSError, context: Context) -> String {
        switch error {
        case .notAuthenticated, .noRefreshToken:
            return String(localized: "Your session has expired. Sign in again to continue.")
        case .authenticationCancelled:
            return String(localized: "Sign-in was cancelled.")
        case .authenticationFailed:
            return String(localized: "Sign-in didn't complete. Try again.")
        case .invalidURL:
            return context.fallback
        case .decodingFailed:
            return String(localized: "Vélo'v sent back something this app didn't understand.")
        case .httpError(let statusCode, let body):
            switch statusCode {
            case 401:
                return String(localized: "Your session has expired. Sign in again to continue.")
            case 403:
                // A 403 means two different things on this API: a rejected token, or an endpoint
                // this account is simply not allowed to call.
                return isTokenRejection(body)
                    ? String(localized: "Your session has expired. Sign in again to continue.")
                    : context.notPermitted
            case 404:
                return context.notFound
            case 409:
                return String(localized: "That conflicts with something already in progress — pull to refresh and check.")
            case 429:
                return String(localized: "Too many requests just now. Wait a moment and try again.")
            case 500...599:
                return String(localized: "Vélo'v's servers are having trouble. Try again in a moment.")
            default:
                return context.fallback
            }
        }
    }

    private static func message(for error: URLError, context: Context) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return String(localized: "You appear to be offline. Check your connection and try again.")
        case .timedOut:
            return String(localized: "That took too long. Check your connection and try again.")
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return String(localized: "Couldn't reach Vélo'v. Try again in a moment.")
        case .cancelled:
            return context.fallback
        default:
            return context.fallback
        }
    }

    /// True when a 403 body looks like the server rejecting the *token* rather than the *endpoint*.
    static func isTokenRejection(_ body: Data?) -> Bool {
        guard let body, let text = String(data: body, encoding: .utf8)?.lowercased() else {
            // With no body the cause is ambiguous; treat it as an endpoint refusal rather than
            // pushing the rider through a needless re-sign-in.
            return false
        }
        if text.contains("role.not.allowed") || text.contains("not_allowed") {
            return false
        }
        return text.contains("takn")
            || text.contains("invalid_token")
            || text.contains("invalid token")
            || text.contains("token_expired")
            || text.contains("token expired")
    }

    /// The rider gets the plain sentence; the developer gets the real error.
    private static func log(_ error: Error, context: Context) {
#if DEBUG
        if case .httpError(let statusCode, let body) = error as? VLSError ?? .invalidURL {
            let bodyText = body.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            print("[OpenVeloV] \(context) failed: HTTP \(statusCode) — \(bodyText.prefix(300))")
        } else {
            print("[OpenVeloV] \(context) failed: \(error.localizedDescription)")
        }
#endif
    }
}
