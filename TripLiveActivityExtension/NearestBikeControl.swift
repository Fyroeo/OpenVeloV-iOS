import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct NearestBikeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NearestBikeControl") {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.nearestBike)) {
                Label("Nearest Bike", systemImage: "bicycle")
            }
        }
        .displayName("Nearest Vélo'v")
        .description("Opens OpenVeloV on the closest station with a bike.")
    }
}

@available(iOS 18.0, *)
struct NearestDockControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NearestDockControl") {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.nearestDock)) {
                Label("Nearest Dock", systemImage: "parkingsign")
            }
        }
        .displayName("Nearest Vélo'v dock")
        .description("Opens OpenVeloV on the closest station with a free dock.")
    }
}
