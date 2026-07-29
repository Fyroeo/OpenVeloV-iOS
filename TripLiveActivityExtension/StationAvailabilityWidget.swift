import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct StationEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Station" }
    static var defaultQuery = StationEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct StationEntityQuery: EntityStringQuery {
    func entities(for identifiers: [StationEntity.ID]) async throws -> [StationEntity] {
        let wanted = Set(identifiers)
        return try await StationWidgetData.allStations()
            .filter { wanted.contains($0.number) }
            .map { StationEntity(id: $0.number, name: $0.name) }
    }

    func entities(matching string: String) async throws -> [StationEntity] {
        try await StationWidgetData.allStations()
            .filter { $0.name.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .prefix(40)
            .map { StationEntity(id: $0.number, name: $0.name) }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        try await StationWidgetData.allStations()
            .sorted { $0.name < $1.name }
            .prefix(40)
            .map { StationEntity(id: $0.number, name: $0.name) }
    }
}

enum StationWidgetMetric: String, AppEnum {
    case bikes
    case electric
    case docks

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Show" }
    static var caseDisplayRepresentations: [StationWidgetMetric: DisplayRepresentation] = [
        .bikes: "All bikes",
        .electric: "Electric bikes",
        .docks: "Free docks"
    ]

    func count(for station: StationSnapshot) -> Int {
        switch self {
        case .bikes: return station.totalBikes
        case .electric: return station.electricalBikes
        case .docks: return station.docksAvailable
        }
    }

    var label: String {
        switch self {
        case .bikes: return String(localized: "bikes")
        case .electric: return String(localized: "e-bikes")
        case .docks: return String(localized: "docks")
        }
    }

    /// SF Symbol names, so unlike `label` these must never be localized.
    var systemImage: String {
        switch self {
        case .bikes: return "bicycle"
        case .electric: return "bolt.fill"
        case .docks: return "parkingsign"
        }
    }
}

struct SelectStationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Choose Station" }
    static var description: IntentDescription {
        IntentDescription("Pick a station to watch, or leave it empty to follow whichever one is nearest.")
    }

    @Parameter(title: "Station")
    var station: StationEntity?

    @Parameter(title: "Show", default: .bikes)
    var metric: StationWidgetMetric

    init() {}

    init(station: StationEntity?, metric: StationWidgetMetric) {
        self.station = station
        self.metric = metric
    }
}

// MARK: - Timeline

struct StationWidgetEntry: TimelineEntry {
    let date: Date
    let station: StationSnapshot?
    let metric: StationWidgetMetric
    let isNearest: Bool
    /// True when the fetch failed, not merely when the data is old.
    let isStale: Bool

    static let placeholder = StationWidgetEntry(
        date: Date(),
        station: .placeholder,
        metric: .bikes,
        isNearest: false,
        isStale: false
    )
}

struct StationWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StationWidgetEntry { .placeholder }

    func snapshot(for configuration: SelectStationIntent, in context: Context) async -> StationWidgetEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: SelectStationIntent, in context: Context) async -> Timeline<StationWidgetEntry> {
        let current = await entry(for: configuration)
        // Widget refreshes are rationed; 15 min keeps data useful without burning the budget.
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [current], policy: .after(next))
    }

    private func entry(for configuration: SelectStationIntent) async -> StationWidgetEntry {
        let metric = configuration.metric
        do {
            if let selected = configuration.station {
                let station = try await StationWidgetData.station(number: selected.id)
                return StationWidgetEntry(date: Date(), station: station, metric: metric, isNearest: false, isStale: false)
            }
            guard let coordinate = WidgetLocation.current else {
                return StationWidgetEntry(date: Date(), station: nil, metric: metric, isNearest: true, isStale: false)
            }
            let station = try await StationWidgetData.nearestStation(to: coordinate)
            return StationWidgetEntry(date: Date(), station: station, metric: metric, isNearest: true, isStale: false)
        } catch {
            return StationWidgetEntry(
                date: Date(),
                station: nil,
                metric: metric,
                isNearest: configuration.station == nil,
                isStale: true
            )
        }
    }
}

// MARK: - Views

struct StationAvailabilityWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "StationAvailabilityWidget",
            intent: SelectStationIntent.self,
            provider: StationWidgetProvider()
        ) { entry in
            StationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.station.map { DeepLink.station(number: $0.number) } ?? DeepLink.nearestBike)
        }
        .configurationDisplayName("Station Availability")
        .description("Live bikes or free docks at a station you pick, or the one nearest to you.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct StationWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StationWidgetEntry

    private var count: Int? {
        entry.station.map { entry.metric.count(for: $0) }
    }

    private var tint: Color {
        guard let station = entry.station else { return .gray }
        let usable = entry.metric == .docks ? station.isReturning : station.isRenting
        guard usable, let count else { return .gray }
        switch count {
        case 0: return .red
        case 1...3: return .orange
        default: return .green
        }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(count.map(String.init) ?? "—") \(entry.metric.label)", systemImage: entry.metric.systemImage)
        case .accessoryCircular:
            Gauge(value: Double(min(count ?? 0, 20)), in: 0...20) {
                Image(systemName: entry.metric.systemImage)
            } currentValueLabel: {
                Text(count.map(String.init) ?? "—")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.station?.name ?? String(localized: "No station"))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Label("\(count.map(String.init) ?? "—") \(entry.metric.label)", systemImage: entry.metric.systemImage)
                    .font(.caption2)
                if let station = entry.station, family == .accessoryRectangular {
                    Text("\(station.mechanicalBikes) mech · \(station.electricalBikes) elec · \(station.docksAvailable) docks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: entry.isNearest ? "location.fill" : "mappin.circle.fill")
                    .font(.caption2)
                (entry.isNearest ? Text("Nearest") : Text("Station"))
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if let station = entry.station, let count {
                Text("\(count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(entry.metric.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(station.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(2)
            } else {
                unavailableBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: entry.isNearest ? "location.fill" : "mappin.circle.fill")
                    (entry.isNearest ? Text("Nearest station") : Text("Station"))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                Text(entry.station?.name ?? String(localized: "Unavailable"))
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 0)

                if let station = entry.station {
                    HStack(spacing: 12) {
                        metric(count: station.mechanicalBikes, systemImage: "bicycle", tint: .red)
                        metric(count: station.electricalBikes, systemImage: "bolt.fill", tint: .green)
                        metric(count: station.docksAvailable, systemImage: "parkingsign", tint: .secondary)
                    }
                    .font(.caption)
                }
            }

            Spacer(minLength: 0)

            if let count {
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(entry.metric.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var unavailableBody: some View {
        if entry.isStale {
            Text("Couldn't refresh")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if entry.isNearest {
            Text("Location access needed to find your nearest station.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("Station unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metric(count: Int, systemImage: String, tint: Color) -> some View {
        Label("\(count)", systemImage: systemImage)
            .foregroundStyle(tint)
    }
}
