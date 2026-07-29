import ActivityKit
import BackgroundTasks
import Foundation
import VLSKit

/// Lets iOS wake the app to reconcile Live Activities, which nothing else updates once the
/// foreground pollers are suspended. A background launch has no `TripViewModel` or
/// `BookingViewModel` to read from, so this works off `Activity.activities`, which the OS keeps
/// across process relaunches.
enum BackgroundRefreshManager {
    static let taskIdentifier = "net.socialeo.openvelov.refresh"

    /// Must run before the app finishes launching: BGTaskScheduler refuses handlers registered
    /// any later.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handle(refreshTask)
        }
    }

    /// Call when the app moves to the background. Many Vélo'v rides finish inside 15 minutes, so a
    /// running ride or hold asks for 2 minutes rather than risk missing the whole thing; iOS treats
    /// either delay as a hint and may run the task much later.
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

        // A client of its own rather than the app's: the shared keychain carries the session, so
        // there is nothing to sign in to here.
        let client = VLSClient(environment: AppSecrets.environment, tokenStore: KeychainTokenStore())
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
