import Foundation
import VLSKit

/// The single app-wide authenticated client.
///
/// One `AuthSession` per process matters: two sessions sharing the same Keychain tokens can each
/// refresh - and Keycloak rotates refresh tokens, so the second refresh invalidates the first and
/// silently logs the user out. Both the UI (`AuthViewModel`) and the WatchConnectivity unlock
/// handler (`WatchUnlockService`) go through this one instance.
enum AppClient {
    static let shared = VLSClient(environment: AppSecrets.environment, tokenStore: KeychainTokenStore())
}
