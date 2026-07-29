import ActivityKit
import Foundation

/// Compiled into both the app and the Live Activity extension (see the two `Shared` entries in
/// project.yml), so it must stay free of any app-only dependency.
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var bikeNumber: Int
        var stationName: String
        var isElectric: Bool
    }
}
