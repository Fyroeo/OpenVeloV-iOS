import ActivityKit
import Foundation
import VLSKit

/// Starts, updates, and ends the "ride in progress" Live Activity.
///
/// This is best effort. Live Activities can be unavailable, for example when the user disables them in Settings or the device does not support them. ActivityKit reports this as a thrown error. The code ignores the error, because there is no useful action to show the user for this background convenience feature.
@MainActor
enum LiveActivityManager {
    private static var currentActivity: Activity<TripActivityAttributes>?
    private static var currentBookingActivity: Activity<BookingActivityAttributes>?

    static func start(trip: Trip) {
        guard currentActivity == nil else {
            update(trip: trip)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: contentState(for: trip), staleDate: nil)
        currentActivity = try? Activity.request(attributes: TripActivityAttributes(), content: content)
    }

    static func update(trip: Trip) {
        guard let currentActivity else { return }
        let content = ActivityContent(state: contentState(for: trip), staleDate: nil)
        Task { await currentActivity.update(content) }
    }

    static func endCurrent() {
        guard let activity = currentActivity else { return }
        currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private static func contentState(for trip: Trip) -> TripActivityAttributes.ContentState {
        TripActivityAttributes.ContentState(
            startDate: trip.startDateTime ?? Date(),
            bikeNumber: trip.bikeNumber ?? 0,
            stationName: trip.startStationName ?? "Vélo'v station",
            isElectric: trip.bikeType == .electrical
        )
    }

    static func startBooking(endDate: Date, bikeNumber: Int, stationName: String, standNumber: Int?, isElectric: Bool) {
        guard currentBookingActivity == nil else {
            updateBooking(endDate: endDate, bikeNumber: bikeNumber, stationName: stationName, standNumber: standNumber, isElectric: isElectric)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = BookingActivityAttributes.ContentState(endDate: endDate, bikeNumber: bikeNumber, stationName: stationName, standNumber: standNumber, isElectric: isElectric)
        let content = ActivityContent(state: state, staleDate: endDate)
        currentBookingActivity = try? Activity.request(attributes: BookingActivityAttributes(), content: content)
    }

    static func updateBooking(endDate: Date, bikeNumber: Int, stationName: String, standNumber: Int?, isElectric: Bool) {
        guard let currentBookingActivity else { return }
        let state = BookingActivityAttributes.ContentState(endDate: endDate, bikeNumber: bikeNumber, stationName: stationName, standNumber: standNumber, isElectric: isElectric)
        let content = ActivityContent(state: state, staleDate: endDate)
        Task { await currentBookingActivity.update(content) }
    }

    static func endBookingActivity() {
        guard let activity = currentBookingActivity else { return }
        currentBookingActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
