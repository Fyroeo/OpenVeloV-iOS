import Foundation
import UserNotifications
import VLSKit

/// Sends local notifications for two events: a ride ends (the bike docks), or a booking hold expires.
/// This is best effort. If the user does not grant notification permission, the app does not post or schedule the notification.
/// The app detects the ride end by polling, not by a server push. The ride-ended notification fires only while the app is active.
/// The app schedules the booking-expiry notification as an OS-level timed alert at booking time. This notification fires even when the app is not running.
@MainActor
enum NotificationManager {
    private static let bookingExpiryIdentifier = "booking-expiry"

    static func requestAuthorizationIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func notifyRideEnded(trip: Trip) {
        let content = UNMutableNotificationContent()
        content.title = "Ride Ended"
        if let bikeNumber = trip.bikeNumber {
            content.body = "Bike #\(bikeNumber) is docked. \(durationText(for: trip) ?? "Enjoy the rest of your day!")"
        } else {
            content.body = durationText(for: trip) ?? "Your bike is docked."
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ride-ended-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleBookingExpiry(endDate: Date, bikeNumber: Int, stationName: String) {
        cancelBookingExpiry()
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Booking Expired"
        content.body = bikeNumber > 0
            ? "Your hold on bike #\(bikeNumber) at \(stationName) has expired."
            : "Your bike hold at \(stationName) has expired."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: bookingExpiryIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelBookingExpiry() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [bookingExpiryIdentifier])
    }

    private static func durationText(for trip: Trip) -> String? {
        guard let start = trip.startDateTime, let end = trip.endDateTime else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        guard let duration = formatter.string(from: end.timeIntervalSince(start)) else { return nil }
        return "Ride lasted \(duration)."
    }
}
