import CoreLocation
import Foundation
import MapKit

struct MapCluster: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let stations: [MapStation]

    var isSingle: Bool { stations.count == 1 }
    var single: MapStation? { stations.count == 1 ? stations[0] : nil }

    func count(for mode: MapNumberMode) -> Int {
        stations.reduce(0) { $0 + mode.count(for: $1) }
    }

    func isAvailable(for mode: MapNumberMode) -> Bool {
        stations.contains { mode.isAvailable(at: $0) }
    }

    func availability(for mode: MapNumberMode) -> AvailabilityLevel {
        guard isAvailable(for: mode) else { return .none }
        // The cluster reports its best station rather than an average: one good station is enough.
        let levels = stations.filter { mode.isAvailable(at: $0) }.map { mode.availability(for: $0) }
        if levels.contains(.plenty) { return .plenty }
        if levels.contains(.few) { return .few }
        return .none
    }

    /// The region that fits every station in the cluster, for zooming in on tap.
    var boundingRegion: MKCoordinateRegion {
        let latitudes = stations.map(\.coordinate.latitude)
        let longitudes = stations.map(\.coordinate.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else {
            return MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLatitude - minLatitude) * 2.2, 0.004),
                longitudeDelta: max((maxLongitude - minLongitude) * 2.2, 0.004)
            )
        )
    }

    static func == (lhs: MapCluster, rhs: MapCluster) -> Bool { lhs.id == rhs.id }
}

enum MapClusterer {

    /// Below this span — very roughly a few city blocks — every station gets its own pin.
    static let clusteringDisabledBelowSpan: CLLocationDegrees = 0.011

    /// How many grid cells span the visible region.
    static let gridDivisions: Double = 11

    static let neighbourMergeThreshold: Double = 0.5

    static func clusters(
        for stations: [MapStation],
        in region: MKCoordinateRegion,
        gridDivisions: Double = gridDivisions
    ) -> [MapCluster] {
        let visible = stationsVisible(in: region, from: stations)

        guard region.span.latitudeDelta > clusteringDisabledBelowSpan else {
            return visible.map { MapCluster(id: $0.id, coordinate: $0.coordinate, stations: [$0]) }
        }

        let latitudeCell = max(region.span.latitudeDelta / gridDivisions, .leastNormalMagnitude)
        let longitudeCell = max(region.span.longitudeDelta / gridDivisions, .leastNormalMagnitude)

        var buckets: [GridKey: [MapStation]] = [:]
        for station in visible {
            let key = GridKey(
                row: Int((station.coordinate.latitude / latitudeCell).rounded(.down)),
                column: Int((station.coordinate.longitude / longitudeCell).rounded(.down))
            )
            buckets[key, default: []].append(station)
        }

        buckets = mergeAdjacentBuckets(buckets, latitudeCell: latitudeCell, longitudeCell: longitudeCell)

        return buckets.map { _, group in
            // A cluster sits at the mean of its members rather than at the cell centre.
            let latitude = group.reduce(0.0) { $0 + $1.coordinate.latitude } / Double(group.count)
            let longitude = group.reduce(0.0) { $0 + $1.coordinate.longitude } / Double(group.count)
            let sorted = group.sorted { $0.id < $1.id }
            return MapCluster(
                // Identity comes from the members, not the grid cell, whose key shifts on every zoom.
                id: sorted.map(\.id).joined(separator: "-"),
                coordinate: sorted.count == 1 ? sorted[0].coordinate : CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                stations: sorted
            )
        }
        .sorted { $0.id < $1.id }
    }

    /// Visible region widened by half a screen, so pins are in place before the rider pans.
    static func stationsVisible(in region: MKCoordinateRegion, from stations: [MapStation]) -> [MapStation] {
        let latitudeMargin = region.span.latitudeDelta * 0.75
        let longitudeMargin = region.span.longitudeDelta * 0.75
        let minLatitude = region.center.latitude - latitudeMargin
        let maxLatitude = region.center.latitude + latitudeMargin
        let minLongitude = region.center.longitude - longitudeMargin
        let maxLongitude = region.center.longitude + longitudeMargin

        return stations.filter { station in
            station.coordinate.latitude >= minLatitude && station.coordinate.latitude <= maxLatitude
                && station.coordinate.longitude >= minLongitude && station.coordinate.longitude <= maxLongitude
        }
    }

    /// Merges neighbouring cells whose centroids nearly coincide, so a cell boundary cutting through
    /// one group of stations does not produce two pins sitting on top of each other.
    private static func mergeAdjacentBuckets(
        _ buckets: [GridKey: [MapStation]],
        latitudeCell: CLLocationDegrees,
        longitudeCell: CLLocationDegrees
    ) -> [GridKey: [MapStation]] {
        guard buckets.count > 1 else { return buckets }

        let centroids = buckets.mapValues(centroid(of:))
        var parent: [GridKey: GridKey] = [:]

        func root(_ key: GridKey) -> GridKey {
            var current = key
            while let next = parent[current], next != current {
                current = next
            }
            return current
        }

        func union(_ lhs: GridKey, _ rhs: GridKey) {
            let lhsRoot = root(lhs)
            let rhsRoot = root(rhs)
            guard lhsRoot != rhsRoot else { return }
            // Lowest key wins, so the result does not depend on dictionary iteration order.
            if (lhsRoot.row, lhsRoot.column) < (rhsRoot.row, rhsRoot.column) {
                parent[rhsRoot] = lhsRoot
            } else {
                parent[lhsRoot] = rhsRoot
            }
        }

        for (key, keyCentroid) in centroids {
            for rowOffset in -1...1 {
                for columnOffset in -1...1 where !(rowOffset == 0 && columnOffset == 0) {
                    let neighbour = GridKey(row: key.row + rowOffset, column: key.column + columnOffset)
                    guard let neighbourCentroid = centroids[neighbour] else { continue }
                    let latitudeGap = (keyCentroid.latitude - neighbourCentroid.latitude) / latitudeCell
                    let longitudeGap = (keyCentroid.longitude - neighbourCentroid.longitude) / longitudeCell
                    let separation = (latitudeGap * latitudeGap + longitudeGap * longitudeGap).squareRoot()
                    if separation < neighbourMergeThreshold {
                        union(key, neighbour)
                    }
                }
            }
        }

        guard !parent.isEmpty else { return buckets }

        var merged: [GridKey: [MapStation]] = [:]
        for (key, group) in buckets {
            merged[root(key), default: []].append(contentsOf: group)
        }
        return merged
    }

    private static func centroid(of stations: [MapStation]) -> CLLocationCoordinate2D {
        let count = Double(stations.count)
        return CLLocationCoordinate2D(
            latitude: stations.reduce(0.0) { $0 + $1.coordinate.latitude } / count,
            longitude: stations.reduce(0.0) { $0 + $1.coordinate.longitude } / count
        )
    }

    private struct GridKey: Hashable, Comparable {
        let row: Int
        let column: Int

        static func < (lhs: GridKey, rhs: GridKey) -> Bool {
            (lhs.row, lhs.column) < (rhs.row, rhs.column)
        }
    }
}
