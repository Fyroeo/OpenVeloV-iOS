import SwiftUI
import WidgetKit

@main
struct TripLiveActivityExtensionBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivity()
        BookingLiveActivity()
        StationAvailabilityWidget()
        if #available(iOS 18.0, *) {
            NearestBikeControl()
            NearestDockControl()
        }
    }
}
