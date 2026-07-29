import Foundation
import VLSKit
import VLSKitUI

@MainActor
final class AuthViewModel: ObservableObject {
    let client: VLSClient

    @Published private(set) var isAuthenticated = false
    @Published private(set) var account: Account?
    @Published private(set) var isLoadingAccount = false
    @Published private(set) var reward: Reward?
    @Published private(set) var rewardAutoSpend = false
    /// Blocking account statuses (e.g. `NO_VALID_SUBSCRIPTIONS`). Loaded with the account,
    /// so the app can explain up front why booking or unlocking will fail.
    @Published private(set) var blockingAlerts: [Alert] = []
    @Published var isPresentingLogin = false
    @Published private(set) var pendingAuthorization: PendingAuthorization?
    @Published var errorMessage: String?

    private(set) var accountId: UUID?
    private var activeSubscriptionId: UUID?

    /// Favourites live in `FavoritesStore` so they keep working signed out.
    private let favorites: FavoritesStore

    var onAccountLoaded: ((UUID) async -> Void)?

    /// Not a bare `VLSEnvironment.lyon`: that preset ships empty web-client credentials, and
    /// authenticated calls also need the anonymous `Authorization: Taknv1` token minted from them.
    init(environment: VLSEnvironment = AppSecrets.environment, favorites: FavoritesStore) {
        self.client = VLSClient(environment: environment, tokenStore: KeychainTokenStore())
        self.favorites = favorites
    }

    var redirectURI: URL { client.environment.oidcRedirectURI }

    var rewardBalance: Int? { reward?.balance }

    /// A rider-facing reason the account can't ride, or `nil` if nothing blocks it.
    var blockingAlertMessage: String? {
        guard let alert = blockingAlerts.first else { return nil }
        switch alert.value {
        case "NO_VALID_SUBSCRIPTIONS":
            return String(localized: "You have no active Vélo'v subscription, so booking and unlocking are unavailable.")
        default:
            return String(localized: "Your Vélo'v account has a hold that prevents booking and unlocking.")
        }
    }

    var displayName: String? {
        guard let account else { return nil }
        let fullName = [account.firstName, account.lastName].compactMap { $0 }.joined(separator: " ")
        return fullName.isEmpty ? nil : fullName
    }

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
                errorMessage = UserFacingError.message(for: error, context: .account)
            }
        }
    }

    func logout() async {
        await client.logout()
        await LoginSessionCleaner.clearSession(for: client.environment.iamBaseURL)
        isAuthenticated = false
        account = nil
        accountId = nil
        activeSubscriptionId = nil
        reward = nil
        blockingAlerts = []
        errorMessage = nil
    }

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

    /// Flips the switch optimistically and rolls back to `previous` if the server rejects it.
    func setRewardAutoSpend(_ isOn: Bool) async {
        guard let accountId else { return }
        let previous = rewardAutoSpend
        rewardAutoSpend = isOn
        do {
            let updated = try await client.rewards.update(accountId: accountId, autoSpend: isOn)
            reward = updated
            rewardAutoSpend = updated.autoSpend
        } catch {
            rewardAutoSpend = previous
            errorMessage = UserFacingError.message(for: error, context: .account)
        }
    }

    func refreshReward() async {
        guard let accountId else { return }
        guard let refreshed = try? await client.rewards.reward(accountId: accountId) else { return }
        reward = refreshed
        rewardAutoSpend = refreshed.autoSpend
    }

    private func loadAccount() async {
        guard let email = await client.auth.currentEmail else {
            errorMessage = String(localized: "Couldn't read your identity from the sign-in token. Sign in again.")
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
            errorMessage = nil
            await favorites.sync(remote: loadedAccount.stations, client: client, accountId: resolvedId)
            await refreshReward()
            blockingAlerts = (try? await client.account.alerts(accountId: resolvedId).filter(\.isBlocking)) ?? []
            await onAccountLoaded?(resolvedId)
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .account)
        }
    }
}
