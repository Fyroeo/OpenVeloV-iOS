import ActivityKit
import BackgroundTasks
import Foundation
import VLSKit

/// Runs opportunistic background sync for the 2 Live Activities: the ride timer and the
/// booking hold.
///
/// In the foreground, `TripViewModel` and `BookingViewModel` poll and update these
/// directly. In the background, iOS suspends that polling within seconds, so nothing
/// updates a Live Activity again until the app reopens.
///
/// `BGTaskScheduler` lets iOS wake the app to reconcile them instead. A background
/// launch has no `TripViewModel`/`BookingViewModel` instance to read from, so this code
/// reads `Activity<Attributes>.activities` directly, which persists at the OS level
/// across process relaunches.
///
/// iOS runs this task opportunistically, based on usage and battery level, with a delay
/// from minutes to much longer. This is an improvement over waiting for the app to
/// reopen, not a guarantee.
enum BackgroundRefreshManager {
    static let taskIdentifier = "net.socialeo.openvelov.refresh"

    /// Call once, early in the app life cycle, before the first scene connects.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    /// Call when the app moves to the background, in case a Live Activity is running.
    ///
    /// The delay before iOS runs this task is the main limit on detecting a docked bike
    /// in the background. A fixed 15-minute delay could miss a short ride entirely, since
    /// many Vélo'v rides finish within 15 minutes. This method requests 2 minutes instead
    /// of 15 while a trip or booking Live Activity is active.
    static func scheduleNextRefresh() {
        let hasActiveRideOrBooking = !Activity<TripActivityAttributes>.activities.isEmpty
            || !Activity<BookingActivityAttributes>.activities.isEmpty
        let delay: TimeInterval = hasActiveRideOrBooking ? 2 * 60 : 15 * 60
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        scheduleNextRefresh()
        let work = Task {
            await reconcileLiveActivities()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// Ends a Live Activity whose trip or booking no longer exists on the server.
    private static func reconcileLiveActivities() async {
        let tripActivities = Activity<TripActivityAttributes>.activities
        let bookingActivities = Activity<BookingActivityAttributes>.activities
        guard !tripActivities.isEmpty || !bookingActivities.isEmpty else { return }

        let client = VLSClient(environment: .lyon, tokenStore: KeychainTokenStore())
        guard await client.isAuthenticated,
              let email = await client.auth.currentEmail,
              let accountId = try? await client.account.accountId(email: email) else {
            return
        }

        if !tripActivities.isEmpty {
            let ongoing = (try? await client.trips.ongoingTrips(accountId: accountId)) ?? []
            if ongoing.isEmpty {
                for activity in tripActivities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }

        if !bookingActivities.isEmpty {
            let bookings = (try? await client.bookings.bookings(accountId: accountId)) ?? []
            let stillHeld = bookings.contains { $0.endTime > Date() }
            if !stillHeld {
                for activity in bookingActivities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
