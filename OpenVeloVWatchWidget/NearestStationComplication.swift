import CoreLocation
import SwiftUI
import WidgetKit

struct NearestStationEntry: TimelineEntry {
    let date: Date
    let station: WatchStation?
    let distance: CLLocationDistance?
    let isPlaceholder: Bool
}

struct NearestStationProvider: TimelineProvider {
    func placeholder(in context: Context) -> NearestStationEntry {
        NearestStationEntry(date: Date(), station: .placeholder, distance: 120, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NearestStationEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await entry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NearestStationEntry>) -> Void) {
        Task {
            let entry = await entry()
            // Availability changes minute to minute; a 15-minute cadence balances freshness and budget.
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func entry() async -> NearestStationEntry {
        guard let coordinate = WatchPassiveLocation.current else {
            return NearestStationEntry(date: Date(), station: nil, distance: nil, isPlaceholder: false)
        }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let nearest = try? await WatchStationData.nearby(to: coordinate, limit: 12)
            .first { $0.isRenting && $0.totalBikes > 0 }
        return NearestStationEntry(
            date: Date(),
            station: nearest,
            distance: nearest?.distance(from: here),
            isPlaceholder: false
        )
    }
}

struct NearestStationComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NearestStationComplication", provider: NearestStationProvider()) { entry in
            NearestStationComplicationView(entry: entry)
        }
        .configurationDisplayName("Nearest Bike")
        .description("The closest station with a bike ready to ride.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular, .accessoryCorner])
    }
}

struct NearestStationComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NearestStationEntry

    private var bikeCount: Int { entry.station?.totalBikes ?? 0 }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label(inlineText, systemImage: "bicycle")
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            circular.widgetLabel(inlineText)
        default:
            rectangular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "bicycle").font(.caption2)
                Text("\(bikeCount)").font(.title3.bold())
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(entry.station?.name ?? String(localized: "No bikes nearby")).lineLimit(1)
            } icon: {
                Image(systemName: "bicycle")
            }
            .font(.headline)

            if let station = entry.station {
                HStack(spacing: 8) {
                    Text("\(station.totalBikes) bikes").font(.caption).foregroundStyle(.secondary)
                    if let distance = entry.distance {
                        Text(watchDistanceText(distance)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Open the app to refresh").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var inlineText: String {
        guard let station = entry.station else { return String(localized: "No bikes") }
        return "\(station.totalBikes) @ \(station.name)"
    }
}
