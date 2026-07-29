import Foundation
import VLSKit

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var stationNumbers: Set<Int> = []

    private let defaults: UserDefaults
    private static let storageKey = "favoriteStationNumbers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.array(forKey: Self.storageKey) as? [Int] ?? []
        stationNumbers = Set(stored)
    }

    func contains(_ stationNumber: Int?) -> Bool {
        guard let stationNumber else { return false }
        return stationNumbers.contains(stationNumber)
    }

    func toggle(_ stationNumber: Int, client: VLSClient?, accountId: UUID?) async {
        let wasFavorite = stationNumbers.contains(stationNumber)
        if wasFavorite {
            stationNumbers.remove(stationNumber)
        } else {
            stationNumbers.insert(stationNumber)
        }
        persist()

        guard let client, let accountId else { return }
        do {
            if wasFavorite {
                try await client.stationBookmarks.remove(stationId: stationNumber, accountId: accountId)
            } else {
                try await client.stationBookmarks.add(stationId: stationNumber, accountId: accountId)
            }
        } catch {
            // The local change is deliberately not rolled back; the next sign-in sync reconciles
            // it with the server.
#if DEBUG
            print("[OpenVeloV] favorite sync failed for station \(stationNumber): \(error.localizedDescription)")
#endif
        }
    }

    func sync(remote: Set<Int>, client: VLSClient, accountId: UUID) async {
        let localOnly = stationNumbers.subtracting(remote)
        stationNumbers.formUnion(remote)
        persist()

        for stationNumber in localOnly {
            try? await client.stationBookmarks.add(stationId: stationNumber, accountId: accountId)
        }
    }

    private func persist() {
        defaults.set(Array(stationNumbers).sorted(), forKey: Self.storageKey)
    }
}
