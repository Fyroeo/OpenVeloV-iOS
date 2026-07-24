import ActivityKit
import Foundation

/// The app and the widget extension both compile this file.
/// The app starts, updates, and ends the activity.
/// The widget extension shows the activity.
struct BookingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var bikeNumber: Int
        var stationName: String
        var standNumber: Int?
        var isElectric: Bool
    }
}
