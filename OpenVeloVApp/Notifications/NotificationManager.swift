import Foundation
import UserNotifications
import VLSKit

@MainActor
enum NotificationManager {
    private static let bookingExpiryIdentifier = "booking-expiry"
    private static let rideEndingSoonIdentifier = "ride-ending-soon"
    private static let bookingArrivalIdentifier = "booking-arrival"

    static func requestAuthorizationIfNeeded() {
        Task { await requestAuthorizationAwaitingDecision() }
    }

    @discardableResult
    static func requestAuthorizationAwaitingDecision() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    // MARK: - Ride

    static func notifyRideEnded(trip: Trip) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ride Ended")
        if let bikeNumber = trip.bikeNumber {
            content.body = String(localized: "Bike #\(bikeNumber.identifierText) is docked. \(durationText(for: trip) ?? String(localized: "Enjoy the rest of your day!"))")
        } else {
            content.body = durationText(for: trip) ?? String(localized: "Your bike is docked.")
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ride-ended-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleRideEndingSoon(startDate: Date, freeMinutes: Int, leadMinutes: Int, bikeNumber: Int?) {
        cancelRideEndingSoon()
        let fireDate = startDate.addingTimeInterval(TimeInterval((freeMinutes - leadMinutes) * 60))
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Ride Ending Soon")
        let bikeText = bikeNumber.map { String(localized: " on bike #\($0.identifierText)", comment: "Appended to a notification body, e.g. 'your included 30 minutes on bike #25391'") } ?? ""
        content.body = String(localized: "Your included \(freeMinutes) minutes\(bikeText) run out in \(leadMinutes) min. Find a dock to avoid extra charges.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: rideEndingSoonIdentifier, content: content, trigger: trigger)
        )
    }

    static func cancelRideEndingSoon() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [rideEndingSoonIdentifier])
    }

    // MARK: - Booking

    static func scheduleBookingExpiry(endDate: Date, bikeNumber: Int, stationName: String) {
        cancelBookingExpiry()
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Booking Expired")
        content.body = bikeNumber > 0
            ? String(localized: "Your hold on bike #\(bikeNumber.identifierText) at \(stationName) has expired.")
            : String(localized: "Your bike hold at \(stationName) has expired.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: bookingExpiryIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelBookingExpiry() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [bookingExpiryIdentifier])
    }

    /// Fired by `RideLocationService` on arrival at the station holding a booked bike.
    static func notifyBookingArrival(stationName: String, bikeNumber: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "You're at \(stationName)")
        content.body = bikeNumber > 0
            ? String(localized: "Bike #\(bikeNumber.identifierText) is waiting. Open OpenVeloV to unlock it.")
            : String(localized: "Your held bike is waiting. Open OpenVeloV to unlock it.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: bookingArrivalIdentifier, content: content, trigger: nil)
        )
    }

    static func cancelBookingArrival() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [bookingArrivalIdentifier])
    }

    private static func durationText(for trip: Trip) -> String? {
        guard let start = trip.startDateTime, let end = trip.endDateTime else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        guard let duration = formatter.string(from: end.timeIntervalSince(start)) else { return nil }
        return String(localized: "Ride lasted \(duration).")
    }
}
