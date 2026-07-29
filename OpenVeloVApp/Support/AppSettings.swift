import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("settings.freeRideMinutes") var freeRideMinutes: Int = 30
    @AppStorage("settings.rideEndingAlert") var isRideEndingAlertEnabled: Bool = true
    @AppStorage("settings.rideEndingLeadMinutes") var rideEndingLeadMinutes: Int = 5
    /// The phone traces the ride and uploads it to the account when the ride ends.
    @AppStorage("settings.recordRoutes") var isRouteRecordingEnabled: Bool = false
    /// The phone watches the rider's position for the whole booking hold, not just once.
    @AppStorage("settings.bookingArrivalAlert") var isBookingArrivalAlertEnabled: Bool = false

    static let freeRideOptions = [15, 30, 45, 60]
    static let leadTimeOptions = [3, 5, 10, 15]

    var needsBackgroundLocation: Bool {
        isRouteRecordingEnabled || isBookingArrivalAlertEnabled
    }
}
