import Foundation
import SwiftUI
import VLSKit

/// Aggregate figures derived from a rider's completed trips. All-time, independent of the
/// Impact screen's range picker — streaks and badges only make sense over the whole history.
struct TripMetrics {
    let rideCount: Int
    let electricCount: Int
    let mechanicalCount: Int
    let distinctStations: Int
    let weekendRides: Int
    let weekdayRides: Int
    let earlyRides: Int          // started before 07:00
    let lateRides: Int           // started at or after 22:00
    let totalMinutes: Int
    let longestRideMinutes: Int
    let mostRidesInADay: Int
    let currentStreakWeeks: Int
    let longestStreakWeeks: Int

    /// Rough distance at an assumed 13 km/h city pace; the trip feed carries no per-ride distance.
    var estimatedKilometres: Double { Double(totalMinutes) / 60 * 13 }

    static let empty = TripMetrics(
        rideCount: 0, electricCount: 0, mechanicalCount: 0, distinctStations: 0,
        weekendRides: 0, weekdayRides: 0, earlyRides: 0, lateRides: 0,
        totalMinutes: 0, longestRideMinutes: 0, mostRidesInADay: 0,
        currentStreakWeeks: 0, longestStreakWeeks: 0
    )

    init(
        rideCount: Int, electricCount: Int, mechanicalCount: Int, distinctStations: Int,
        weekendRides: Int, weekdayRides: Int, earlyRides: Int, lateRides: Int,
        totalMinutes: Int, longestRideMinutes: Int, mostRidesInADay: Int,
        currentStreakWeeks: Int, longestStreakWeeks: Int
    ) {
        self.rideCount = rideCount
        self.electricCount = electricCount
        self.mechanicalCount = mechanicalCount
        self.distinctStations = distinctStations
        self.weekendRides = weekendRides
        self.weekdayRides = weekdayRides
        self.earlyRides = earlyRides
        self.lateRides = lateRides
        self.totalMinutes = totalMinutes
        self.longestRideMinutes = longestRideMinutes
        self.mostRidesInADay = mostRidesInADay
        self.currentStreakWeeks = currentStreakWeeks
        self.longestStreakWeeks = longestStreakWeeks
    }

    /// - Parameter completedTrips: trips already filtered to finished/auto-finished rides.
    init(completedTrips trips: [Trip], calendar: Calendar = .current, now: Date = Date()) {
        var electric = 0, weekend = 0, weekday = 0, early = 0, late = 0, minutes = 0, longest = 0
        var stations = Set<Int>()
        var ridesPerDay: [Date: Int] = [:]

        for trip in trips {
            if trip.bikeType == .electrical { electric += 1 }
            if let start = trip.startStation { stations.insert(start) }
            if let end = trip.endStation { stations.insert(end) }

            guard let start = trip.startDateTime else { continue }
            let weekdayIndex = calendar.component(.weekday, from: start)
            if weekdayIndex == 1 || weekdayIndex == 7 { weekend += 1 } else { weekday += 1 }
            let hour = calendar.component(.hour, from: start)
            if hour < 7 { early += 1 }
            if hour >= 22 { late += 1 }
            ridesPerDay[calendar.startOfDay(for: start), default: 0] += 1

            if let end = trip.endDateTime {
                let rideMinutes = Int(end.timeIntervalSince(start) / 60)
                minutes += max(0, rideMinutes)
                longest = max(longest, rideMinutes)
            }
        }

        let streak = TripMetrics.weeklyStreak(completedTrips: trips, calendar: calendar, now: now)
        self.init(
            rideCount: trips.count,
            electricCount: electric,
            mechanicalCount: trips.count - electric,
            distinctStations: stations.count,
            weekendRides: weekend,
            weekdayRides: weekday,
            earlyRides: early,
            lateRides: late,
            totalMinutes: minutes,
            longestRideMinutes: longest,
            mostRidesInADay: ridesPerDay.values.max() ?? 0,
            currentStreakWeeks: streak.current,
            longestStreakWeeks: streak.longest
        )
    }

    /// Consecutive-week riding streaks. A week counts if it holds at least one ride. The current
    /// streak only stands when the most recent riding week is this week or last week.
    static func weeklyStreak(
        completedTrips trips: [Trip],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> (current: Int, longest: Int) {
        let weekStarts = Set(trips.compactMap { trip -> Date? in
            trip.startDateTime.flatMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }
        }).sorted()
        guard let firstWeek = weekStarts.first else { return (0, 0) }

        func weeksBetween(_ a: Date, _ b: Date) -> Int {
            calendar.dateComponents([.weekOfYear], from: a, to: b).weekOfYear ?? 0
        }

        var longest = 1, run = 1
        for index in 1..<max(weekStarts.count, 1) where weekStarts.count > 1 {
            if weeksBetween(weekStarts[index - 1], weekStarts[index]) == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        _ = firstWeek

        // Current streak: walk back from the latest riding week only if it's this or last week.
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let latest = weekStarts.last,
              weeksBetween(latest, thisWeek) <= 1 else {
            return (0, longest)
        }
        var current = 1
        for index in stride(from: weekStarts.count - 1, to: 0, by: -1) {
            if weeksBetween(weekStarts[index - 1], weekStarts[index]) == 1 {
                current += 1
            } else {
                break
            }
        }
        return (current, longest)
    }
}

/// A milestone earned from ride history. `progress`/`goal` drive both the unlocked state and the
/// progress ring shown on locked badges.
struct Achievement: Identifiable, Sendable {
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let goal: Int
    let progress: Int

    var isUnlocked: Bool { progress >= goal }
    var fractionComplete: Double { goal <= 0 ? 1 : min(1, Double(progress) / Double(goal)) }

    static func all(for metrics: TripMetrics) -> [Achievement] {
        [
            Achievement(id: "first-ride", title: "First Ride", detail: "Take your first Vélo'v ride.",
                        systemImage: "figure.outdoor.cycle", tint: .accentColor, goal: 1, progress: metrics.rideCount),
            Achievement(id: "ten-rides", title: "Getting Rolling", detail: "Complete 10 rides.",
                        systemImage: "bicycle", tint: .accentColor, goal: 10, progress: metrics.rideCount),
            Achievement(id: "fifty-rides", title: "Regular", detail: "Complete 50 rides.",
                        systemImage: "bicycle.circle.fill", tint: .blue, goal: 50, progress: metrics.rideCount),
            Achievement(id: "hundred-rides", title: "Centurion", detail: "Complete 100 rides.",
                        systemImage: "rosette", tint: .purple, goal: 100, progress: metrics.rideCount),
            Achievement(id: "explorer", title: "Explorer", detail: "Visit 15 different stations.",
                        systemImage: "map.fill", tint: .teal, goal: 15, progress: metrics.distinctStations),
            Achievement(id: "electric", title: "Electric Avenue", detail: "Take 10 electric rides.",
                        systemImage: "bolt.fill", tint: .green, goal: 10, progress: metrics.electricCount),
            Achievement(id: "purist", title: "Purist", detail: "Take 10 mechanical rides.",
                        systemImage: "gearshape.fill", tint: .red, goal: 10, progress: metrics.mechanicalCount),
            Achievement(id: "early-bird", title: "Early Bird", detail: "Start a ride before 7 a.m.",
                        systemImage: "sunrise.fill", tint: .orange, goal: 1, progress: metrics.earlyRides),
            Achievement(id: "night-owl", title: "Night Owl", detail: "Start a ride after 10 p.m.",
                        systemImage: "moon.stars.fill", tint: .indigo, goal: 1, progress: metrics.lateRides),
            Achievement(id: "weekend-warrior", title: "Weekend Warrior", detail: "Take 10 weekend rides.",
                        systemImage: "beach.umbrella.fill", tint: .cyan, goal: 10, progress: metrics.weekendRides),
            Achievement(id: "commuter", title: "Commuter", detail: "Take 20 weekday rides.",
                        systemImage: "briefcase.fill", tint: .brown, goal: 20, progress: metrics.weekdayRides),
            Achievement(id: "marathoner", title: "The Long Way", detail: "Ride for 60 minutes in one go.",
                        systemImage: "timer", tint: .pink, goal: 60, progress: metrics.longestRideMinutes),
            Achievement(id: "streak-4", title: "On a Roll", detail: "Ride in 4 weeks in a row.",
                        systemImage: "flame.fill", tint: .orange, goal: 4, progress: metrics.longestStreakWeeks),
            Achievement(id: "streak-12", title: "Unstoppable", detail: "Ride in 12 weeks in a row.",
                        systemImage: "flame.circle.fill", tint: .red, goal: 12, progress: metrics.longestStreakWeeks),
        ]
    }
}
