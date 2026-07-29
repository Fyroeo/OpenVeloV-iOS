import Foundation
import VLSKit

/// Credentials injected through `Info.plist` at build time so they never land in source control.
enum AppSecrets {

    static var webClientCode: String { infoValue(for: "VLSWebClientCode") }

    static var webClientKey: String { infoValue(for: "VLSWebClientKey") }

    static var isConfigured: Bool {
        !webClientCode.isEmpty && !webClientKey.isEmpty
    }

    static var environment: VLSEnvironment {
        VLSEnvironment(webClientCode: webClientCode, webClientKey: webClientKey)
    }

    /// `Info.plist` holds `$(VLS_WEB_CLIENT_CODE)`-style references. A value still starting with
    /// `$(` means the xcconfig never got substituted in, so treat it as absent, not a credential.
    private static func infoValue(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return "" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("$(") else { return "" }
        return trimmed
    }
}
