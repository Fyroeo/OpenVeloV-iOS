import XCTest
@testable import OpenVeloV
import VLSKit

final class RideAchievementsTests: XCTestCase {

    // UTC so the "Z" times below map straight to hour-of-day; production uses the device calendar.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Builds a finished trip from ISO start/end and a bike-type code (0 = mechanical).
    private func trip(
        start: String,
        end: String? = nil,
        bikeType: Int = 0,
        startStation: Int? = 100,
        endStation: Int? = 200
    ) -> Trip {
        var fields = ["status": "\"FINISHED\"", "bikeType": "\(bikeType)", "startDateTime": "\"\(start)\""]
        if let end { fields["endDateTime"] = "\"\(end)\"" }
        if let startStation { fields["startStation"] = "\(startStation)" }
        if let endStation { fields["endStation"] = "\(endStation)" }
        let json = "{" + fields.map { "\"\($0)\": \($1)" }.joined(separator: ",") + "}"
        return try! JSONDecoder.vls.decode(Trip.self, from: Data(json.utf8))
    }

    func testEmptyMetrics() {
        let metrics = TripMetrics(completedTrips: [])
        XCTAssertEqual(metrics.rideCount, 0)
        XCTAssertEqual(metrics.currentStreakWeeks, 0)
        XCTAssertEqual(metrics.longestStreakWeeks, 0)
    }

    func testCountsAndSplits() {
        let trips = [
            trip(start: "2026-01-05T08:00:00Z", end: "2026-01-05T08:20:00Z", bikeType: 0, startStation: 1, endStation: 2),
            trip(start: "2026-01-06T23:30:00Z", end: "2026-01-06T23:45:00Z", bikeType: 1, startStation: 2, endStation: 3),
            trip(start: "2026-01-10T06:30:00Z", end: "2026-01-10T07:30:00Z", bikeType: 1, startStation: 3, endStation: 1),
        ]
        let metrics = TripMetrics(completedTrips: trips, calendar: calendar)
        XCTAssertEqual(metrics.rideCount, 3)
        XCTAssertEqual(metrics.electricCount, 2)
        XCTAssertEqual(metrics.mechanicalCount, 1)
        XCTAssertEqual(metrics.distinctStations, 3)
        XCTAssertEqual(metrics.earlyRides, 1)   // the 06:30 start
        XCTAssertEqual(metrics.lateRides, 1)    // the 23:30 start
        XCTAssertEqual(metrics.longestRideMinutes, 60)
    }

    func testLongestStreakCountsConsecutiveWeeks() {
        // Three consecutive Mondays, then a gap, then one more week.
        let trips = [
            trip(start: "2026-01-05T08:00:00Z"),
            trip(start: "2026-01-12T08:00:00Z"),
            trip(start: "2026-01-19T08:00:00Z"),
            trip(start: "2026-02-09T08:00:00Z"),
        ]
        let streak = TripMetrics.weeklyStreak(completedTrips: trips, calendar: calendar)
        XCTAssertEqual(streak.longest, 3)
    }

    func testCurrentStreakBrokenWhenNoRecentRide() {
        let trips = [trip(start: "2020-01-06T08:00:00Z")]
        let streak = TripMetrics.weeklyStreak(
            completedTrips: trips,
            calendar: calendar,
            now: Date(timeIntervalSince1970: 1_770_000_000) // long after 2020
        )
        XCTAssertEqual(streak.current, 0)
        XCTAssertEqual(streak.longest, 1)
    }

    func testAchievementsUnlockAndProgress() {
        let trips = (0..<12).map { trip(start: "2026-01-0\(($0 % 9) + 1)T08:00:00Z") }
        let achievements = Achievement.all(for: TripMetrics(completedTrips: trips, calendar: calendar))
        let firstRide = achievements.first { $0.id == "first-ride" }
        XCTAssertEqual(firstRide?.isUnlocked, true)
        let ten = achievements.first { $0.id == "ten-rides" }
        XCTAssertEqual(ten?.isUnlocked, true)
        let fifty = achievements.first { $0.id == "fifty-rides" }
        XCTAssertEqual(fifty?.isUnlocked, false)
        XCTAssertEqual(fifty?.progress, 12)
    }
}
