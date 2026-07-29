import Foundation
import VLSKit

@MainActor
final class ImpactViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var serverStats: [StatisticsType: Int] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didAttemptServerStats = false

    enum Range: String, CaseIterable, Identifiable {
        case month
        case year
        case allTime

        var id: Self { self }

        var label: String {
            switch self {
            case .month: return String(localized: "30 days")
            case .year: return String(localized: "This year")
            case .allTime: return String(localized: "All time")
            }
        }

        var period: StatisticsPeriod {
            switch self {
            case .month: return .month
            case .year, .allTime: return .year
            }
        }

        func startDate(from now: Date = Date()) -> Date {
            let calendar = Calendar.current
            switch self {
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: now) ?? now
            case .year:
                return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            case .allTime:
                return calendar.date(byAdding: .year, value: -20, to: now) ?? now
            }
        }
    }

    @Published var range: Range = .month {
        didSet {
            guard oldValue != range else { return }
            Task { await load() }
        }
    }

    private let authViewModel: AuthViewModel

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: - Derived from ride history

    var completedTrips: [Trip] {
        let start = range.startDate()
        return trips.filter { trip in
            guard trip.status == .finished || trip.status == .autoFinished else { return false }
            guard let startDate = trip.startDateTime else { return false }
            return startDate >= start
        }
    }

    var rideCount: Int { completedTrips.count }

    var totalDuration: TimeInterval {
        completedTrips.reduce(0) { total, trip in
            guard let start = trip.startDateTime, let end = trip.endDateTime else { return total }
            return total + end.timeIntervalSince(start)
        }
    }

    var averageDuration: TimeInterval {
        rideCount == 0 ? 0 : totalDuration / Double(rideCount)
    }

    var longestTrip: Trip? {
        completedTrips.max { lhs, rhs in duration(of: lhs) < duration(of: rhs) }
    }

    var electricCount: Int { completedTrips.filter { $0.bikeType == .electrical }.count }
    var mechanicalCount: Int { completedTrips.filter { $0.bikeType != .electrical }.count }

    var ridesByWeekday: [(symbol: String, count: Int)] {
        let calendar = Calendar.current
        var counts = [Int](repeating: 0, count: 7)
        for trip in completedTrips {
            guard let start = trip.startDateTime else { continue }
            // `weekday` is 1-based starting at Sunday; +5 mod 7 rotates it so Monday is index 0.
            let index = (calendar.component(.weekday, from: start) + 5) % 7
            counts[index] += 1
        }
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let mondayFirst = Array(symbols[1...]) + [symbols[0]]
        return zip(mondayFirst, counts).map { (symbol: String($0.prefix(1)).uppercased(), count: $1) }
    }

    var busiestHour: Int? {
        let calendar = Calendar.current
        var counts: [Int: Int] = [:]
        for trip in completedTrips {
            guard let start = trip.startDateTime else { continue }
            counts[calendar.component(.hour, from: start), default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Riding time at an assumed 13 km/h city pace. Shown only when the server returns no distance.
    var estimatedDistanceKilometres: Double {
        (totalDuration / 3600) * 13
    }

    var serverDistanceKilometres: Double? {
        // The endpoint documents no unit, but the magnitudes it returns only make sense as metres.
        guard let raw = serverStats[.tripsDistance], raw > 0 else { return nil }
        return Double(raw) / 1000
    }

    var co2SavedKilograms: Double? {
        guard let raw = serverStats[.tripsCO2], raw > 0 else { return nil }
        return Double(raw) / 1000
    }

    var calories: Int? {
        guard let raw = serverStats[.tripsCalories], raw > 0 else { return nil }
        return raw
    }

    // MARK: - Loading

    func load() async {
        guard let accountId = authViewModel.accountId else {
            errorMessage = String(localized: "Sign in to see your impact.")
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            trips = try await authViewModel.client.trips.trips(accountId: accountId)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .trips)
        }

        await loadServerStats(accountId: accountId)
    }

    private func loadServerStats(accountId: UUID) async {
        didAttemptServerStats = true
        // Full ISO datetime, matching what the official web app sends. The endpoint 404s
        // ("No stats found") for accounts with no stats regardless of format, so the
        // Impact screen falls back to figures derived from ride history.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let results = try? await authViewModel.client.statistics.statistics(
            accountId: accountId,
            startDate: formatter.string(from: range.startDate()),
            endDate: formatter.string(from: Date()),
            period: range.period,
            types: [.tripsCO2, .tripsCalories, .tripsDistance, .tripsRewards, .tripsCounts, .tripsDurations]
        )
        guard let results else {
            serverStats = [:]
            return
        }
        serverStats = Dictionary(results.map { ($0.statsType, $0.periodTotal) }, uniquingKeysWith: +)
    }

    private func duration(of trip: Trip) -> TimeInterval {
        guard let start = trip.startDateTime, let end = trip.endDateTime else { return 0 }
        return end.timeIntervalSince(start)
    }
}
