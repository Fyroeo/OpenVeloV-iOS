import Foundation
import VLSKit

/// Loads and periodically refreshes the live station list.
@MainActor
final class StationsViewModel: ObservableObject {
    @Published private(set) var stations: [MapStation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    /// This value increments on every successful refresh.
    /// `MapStation`'s `Equatable` only compares `id`.
    /// So `onChange(of: stations)` does not fire when only the counts change.
    /// Views that must react to any data update should observe this value instead.
    @Published private(set) var updateCount = 0

    private let client: GBFSClient
    private var refreshTask: Task<Void, Never>?

    init(environment: VLSEnvironment = .lyon) {
        client = GBFSClient(contract: environment.contract, environment: environment)
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let informationFeed = client.stationInformation()
            async let statusFeed = client.stationStatus()

            let information = try await informationFeed.data.stations
            let statusByID = Dictionary(uniqueKeysWithValues: try await statusFeed.data.stations.map { ($0.id, $0) })

            stations = information.compactMap { MapStation(information: $0, status: statusByID[$0.id]) }
            updateCount += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes right away, then again every `interval` seconds, until `stopAutoRefresh()` runs.
    /// The feed advertises a `ttl` of 1 second, so no server-side caching window limits
    /// the refresh rate. `interval` is set for a comfortable pace for someone glancing at
    /// the map.
    func startAutoRefresh(interval: TimeInterval = 10) {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
