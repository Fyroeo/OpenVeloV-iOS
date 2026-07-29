import CoreLocation
import Foundation
import VLSKit

@MainActor
final class StationsViewModel: ObservableObject {
    @Published private(set) var stations: [MapStation] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    /// True once a refresh has succeeded at least once.
    @Published private(set) var hasLoaded = false
    @Published private(set) var bonusStationNumbers: Set<Int> = []
    @Published private(set) var updateCount = 0

    private(set) var stationsByNumber: [Int: MapStation] = [:]

    private let client: GBFSClient
    private var refreshTask: Task<Void, Never>?
    private var refreshInterval: TimeInterval = 10

    init(environment: VLSEnvironment = .lyon) {
        client = GBFSClient(contract: environment.contract, environment: environment)
    }

    // MARK: - Loading

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let informationFeed = client.stationInformation()
            async let statusFeed = client.stationStatus()

            let information = try await informationFeed.data.stations
            let statusByID = Dictionary(uniqueKeysWithValues: try await statusFeed.data.stations.map { ($0.id, $0) })

            stations = information.compactMap { MapStation(information: $0, status: statusByID[$0.id]) }
            stationsByNumber = Dictionary(
                stations.compactMap { station in Int(station.id).map { ($0, station) } },
                uniquingKeysWith: { first, _ in first }
            )
            errorMessage = nil
            lastUpdated = Date()
            hasLoaded = true
            updateCount += 1
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .stations)
        }
    }

    /// Refreshes every `interval` seconds until `stopAutoRefresh()` runs; when the last refresh is
    /// still fresher than `interval`, the first tick waits out the remainder instead of refetching.
    func startAutoRefresh(interval: TimeInterval = 10) {
        stopAutoRefresh()
        refreshInterval = interval
        refreshTask = Task { [weak self] in
            guard let self else { return }
            if let lastUpdated = self.lastUpdated {
                let age = Date().timeIntervalSince(lastUpdated)
                if age < interval {
                    try? await Task.sleep(nanoseconds: UInt64((interval - age) * 1_000_000_000))
                }
            }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    var isAutoRefreshing: Bool { refreshTask != nil }

    func resumeAutoRefresh() {
        guard refreshTask == nil else { return }
        startAutoRefresh(interval: refreshInterval)
    }

    /// Set once the bonus endpoint has refused this account, so the app stops asking.
    private var isBonusEndpointUnavailable = false

    func loadBonusStations(client authenticatedClient: VLSClient) async {
        guard !isBonusEndpointUnavailable else { return }
        do {
            let bonusStations = try await authenticatedClient.stations.stations(bonus: true)
            bonusStationNumbers = Set(bonusStations.map(\.number))
        } catch {
            if case .httpError(let statusCode, _) = error as? VLSError ?? .invalidURL, statusCode == 403 {
                isBonusEndpointUnavailable = true
            }
#if DEBUG
            print("[OpenVeloV] bonus stations unavailable: \(error.localizedDescription)")
#endif
        }
    }

    func clearBonusStations() {
        bonusStationNumbers = []
        isBonusEndpointUnavailable = false
    }

    // MARK: - Lookup

    func station(forNumber number: Int?) -> MapStation? {
        guard let number else { return nil }
        return stationsByNumber[number]
    }

    func name(forNumber number: Int?) -> String? {
        guard let number else { return nil }
        return stationsByNumber[number]?.name ?? String(localized: "Station \(number.identifierText)")
    }

    func hasBonus(stationNumber: Int?) -> Bool {
        guard let stationNumber else { return false }
        return bonusStationNumbers.contains(stationNumber)
    }

    /// Matches on name or exact station id, and falls back to the nearest stations on an empty query.
    func search(_ query: String, near location: UserLocation?, limit: Int = 40) -> [MapStation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nearby(to: location, limit: limit) }

        let matches = stations.filter { station in
            station.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || station.id == trimmed
        }
        return sortedByDistance(matches, to: location).prefix(limit).map { $0 }
    }

    func nearby(to location: UserLocation?, limit: Int = 40) -> [MapStation] {
        sortedByDistance(stations, to: location).prefix(limit).map { $0 }
    }

    func nearest(to location: UserLocation?, where isEligible: (MapStation) -> Bool) -> MapStation? {
        guard let location else { return nil }
        return stations
            .filter(isEligible)
            .min { location.distance(to: $0.coordinate) < location.distance(to: $1.coordinate) }
    }

    private func sortedByDistance(_ input: [MapStation], to location: UserLocation?) -> [MapStation] {
        guard let location else { return input.sorted { $0.name < $1.name } }
        return input.sorted { location.distance(to: $0.coordinate) < location.distance(to: $1.coordinate) }
    }
}
