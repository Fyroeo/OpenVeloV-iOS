import ActivityKit
import Foundation

/// Compiled into both the app and the widget extension, which have to agree on this shape.
struct BookingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var bikeNumber: Int
        var stationName: String
        var standNumber: Int?
        var isElectric: Bool
    }
}
