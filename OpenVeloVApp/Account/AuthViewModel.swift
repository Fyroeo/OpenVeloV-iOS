import Foundation
import VLSKit
import VLSKitUI

/// Manages sign-in with `VLSClient`: Keycloak PKCE login and the resulting `Account`.
@MainActor
final class AuthViewModel: ObservableObject {
    let client: VLSClient

    @Published private(set) var isAuthenticated = false
    @Published private(set) var account: Account?
    @Published private(set) var isLoadingAccount = false
    @Published private(set) var rewardBalance: Int?
    @Published var isPresentingLogin = false
    @Published private(set) var pendingAuthorization: PendingAuthorization?
    @Published var errorMessage: String?
    @Published private(set) var favoriteStationNumbers: Set<Int> = []

    private(set) var accountId: UUID?
    private var activeSubscriptionId: UUID?

    init(environment: VLSEnvironment = .lyon) {
        self.client = VLSClient(environment: environment, tokenStore: KeychainTokenStore())
    }

    var redirectURI: URL { client.environment.oidcRedirectURI }

    /// Resumes a session saved in the Keychain.
    func refreshAuthenticationState() async {
        isAuthenticated = await client.isAuthenticated
        guard isAuthenticated else { return }
        await loadAccount()
    }

    func startLogin() async {
        errorMessage = nil
        pendingAuthorization = await client.beginLogin()
        isPresentingLogin = true
    }

    func cancelLogin() {
        isPresentingLogin = false
        pendingAuthorization = nil
    }

    /// Called from `VLSKitUI.LoginView.onRedirect` once sign-in reaches the redirect URI.
    func handleLoginRedirect(_ url: URL) {
        guard let pending = pendingAuthorization else { return }
        isPresentingLogin = false
        pendingAuthorization = nil
        Task {
            do {
                try await client.completeLogin(callbackURL: url, pending: pending)
                isAuthenticated = true
                await loadAccount()
            } catch {
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
            }
        }
    }

    /// Ends the local and Keycloak SSO sessions, and clears the login web view's
    /// cookies so the next sign-in does not silently reuse the old session.
    func logout() async {
        await client.logout()
        await LoginSessionCleaner.clearSession(for: client.environment.iamBaseURL)
        isAuthenticated = false
        account = nil
        accountId = nil
        activeSubscriptionId = nil
        rewardBalance = nil
        favoriteStationNumbers = []
    }

    /// Updates the local set immediately, then reverts it if the server call fails.
    func toggleFavorite(stationNumber: Int) async {
        guard let accountId else { return }
        let wasFavorite = favoriteStationNumbers.contains(stationNumber)
        if wasFavorite {
            favoriteStationNumbers.remove(stationNumber)
        } else {
            favoriteStationNumbers.insert(stationNumber)
        }
        do {
            if wasFavorite {
                try await client.stationBookmarks.remove(stationId: stationNumber, accountId: accountId)
            } else {
                try await client.stationBookmarks.add(stationId: stationNumber, accountId: accountId)
            }
        } catch {
            if wasFavorite {
                favoriteStationNumbers.insert(stationNumber)
            } else {
                favoriteStationNumbers.remove(stationNumber)
            }
        }
    }

    func isFavorite(stationNumber: Int) -> Bool {
        favoriteStationNumbers.contains(stationNumber)
    }

    /// Finds a subscription that is not locked and has a period covering now. Derives
    /// "current" from `validityStart`/`validityEnd` rather than `SubscriptionPeriod.type`,
    /// since the server always returns `nil` for that field.
    func resolveActiveSubscriptionId() async throws -> UUID {
        if let activeSubscriptionId {
            return activeSubscriptionId
        }
        guard let accountId else {
            throw UnlockError.notAuthenticated
        }
        let now = Date()
        let subscriptions = try await client.subscriptions.subscriptions(accountId: accountId)
        guard let usable = subscriptions.first(where: { subscription in
            !subscription.isLocked && subscription.periods.contains { $0.validityStart <= now && now <= $0.validityEnd }
        }) else {
            let debugInfo: String
            if subscriptions.isEmpty {
                debugInfo = "0 subscriptions returned"
            } else {
                debugInfo = subscriptions.map { subscription in
                    let periods = subscription.periods.map { "\($0.validityStart)...\($0.validityEnd)" }.joined(separator: ",")
                    return "type=\(subscription.type?.rawValue ?? "nil") isLocked=\(subscription.isLocked) periods=[\(periods)]"
                }.joined(separator: "; ")
            }
            throw UnlockError.noActiveSubscription(debugInfo: debugInfo)
        }
        activeSubscriptionId = usable.id
        return usable.id
    }

    private func loadAccount() async {
        guard let email = await client.auth.currentEmail else {
            errorMessage = "Couldn't read identity from ID token"
            return
        }
        isLoadingAccount = true
        defer { isLoadingAccount = false }
        do {
            let resolvedId: UUID
            if let accountId {
                resolvedId = accountId
            } else {
                resolvedId = try await client.account.accountId(email: email)
                accountId = resolvedId
            }
            let loadedAccount = try await client.account.account(accountId: resolvedId)
            account = loadedAccount
            favoriteStationNumbers = loadedAccount.stations
            rewardBalance = try? await client.rewards.reward(accountId: resolvedId).balance
        } catch {
            errorMessage = "Couldn't load account: \(error.localizedDescription)"
        }
    }
}
