import ActivityKit
import Foundation

/// The app and the widget extension both compile this file.
/// The app starts, updates, and ends the activity.
/// The widget extension shows the activity.
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var bikeNumber: Int
        var stationName: String
        var isElectric: Bool
    }
}
