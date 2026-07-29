import CoreLocation
import MapKit
import XCTest
@testable import OpenVeloV

final class MapClustererTests: XCTestCase {

    private func station(
        _ id: String,
        latitude: Double,
        longitude: Double,
        mechanical: Int = 2,
        electrical: Int = 2,
        docks: Int = 5,
        renting: Bool = true,
        returning: Bool = true
    ) -> MapStation {
        MapStation(
            id: id,
            name: "Station \(id)",
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            capacity: 20,
            mechanicalBikes: mechanical,
            electricalBikes: electrical,
            docksAvailable: docks,
            isRenting: renting,
            isReturning: returning
        )
    }

    private func region(span: CLLocationDegrees, center: CLLocationCoordinate2D = .init(latitude: 45.75, longitude: 4.85)) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }

    func testZoomedInReturnsOnePinPerStation() {
        let stations = [
            station("1", latitude: 45.7500, longitude: 4.8500),
            station("2", latitude: 45.7501, longitude: 4.8501),
            station("3", latitude: 45.7502, longitude: 4.8502)
        ]
        let clusters = MapClusterer.clusters(for: stations, in: region(span: 0.005))
        XCTAssertEqual(clusters.count, 3)
        XCTAssertTrue(clusters.allSatisfy(\.isSingle))
    }

    func testZoomedOutMergesNeighbours() {
        let stations = [
            station("1", latitude: 45.7500, longitude: 4.8500),
            station("2", latitude: 45.7501, longitude: 4.8501),
            station("3", latitude: 45.7502, longitude: 4.8502)
        ]
        let clusters = MapClusterer.clusters(for: stations, in: region(span: 0.05))
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].stations.count, 3)
    }

    func testStationsOutsideTheRegionAreDropped() {
        let stations = [
            station("near", latitude: 45.75, longitude: 4.85),
            station("far", latitude: 48.85, longitude: 2.35) // Paris
        ]
        let clusters = MapClusterer.clusters(for: stations, in: region(span: 0.05))
        XCTAssertEqual(clusters.flatMap(\.stations).map(\.id), ["near"])
    }

    func testClusterIDIsStableAcrossPans() {
        let stations = [
            station("1", latitude: 45.7500, longitude: 4.8500),
            station("2", latitude: 45.7501, longitude: 4.8501)
        ]
        let first = MapClusterer.clusters(for: stations, in: region(span: 0.05))
        let second = MapClusterer.clusters(
            for: stations,
            in: region(span: 0.05, center: CLLocationCoordinate2D(latitude: 45.7505, longitude: 4.8505))
        )
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testClusterCountSumsTheModesValue() {
        let stations = [
            station("1", latitude: 45.7500, longitude: 4.8500, mechanical: 3, electrical: 1, docks: 4),
            station("2", latitude: 45.7501, longitude: 4.8501, mechanical: 2, electrical: 5, docks: 6)
        ]
        let cluster = MapClusterer.clusters(for: stations, in: region(span: 0.05))[0]
        XCTAssertEqual(cluster.count(for: .all), 11)
        XCTAssertEqual(cluster.count(for: .electrical), 6)
        XCTAssertEqual(cluster.count(for: .parking), 10)
    }

    func testClusterTakesTheBestAvailabilityOfItsMembers() {
        let stations = [
            station("empty", latitude: 45.7500, longitude: 4.8500, mechanical: 0, electrical: 0),
            station("full", latitude: 45.7501, longitude: 4.8501, mechanical: 6, electrical: 4)
        ]
        let cluster = MapClusterer.clusters(for: stations, in: region(span: 0.05))[0]
        // Best-of, not average: one station with bikes is what makes the group worth walking to.
        XCTAssertEqual(cluster.availability(for: .all), .plenty)
    }

    func testClosedStationsCountAsUnavailable() {
        let closed = station("closed", latitude: 45.75, longitude: 4.85, mechanical: 5, electrical: 5, renting: false)
        let cluster = MapClusterer.clusters(for: [closed], in: region(span: 0.05))[0]
        XCTAssertFalse(cluster.isAvailable(for: .all))
        XCTAssertEqual(cluster.availability(for: .all), AvailabilityLevel.none)
    }

    func testBoundingRegionCoversEveryMember() {
        // Built by hand, not via the clusterer: these two are about 2.7 km apart, so no real
        // clustering pass would ever put them in the same group.
        let cluster = MapCluster(
            id: "1-2",
            coordinate: CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85),
            stations: [
                station("1", latitude: 45.7400, longitude: 4.8400),
                station("2", latitude: 45.7600, longitude: 4.8600)
            ]
        )
        let bounds = cluster.boundingRegion
        XCTAssertEqual(bounds.center.latitude, 45.75, accuracy: 0.0001)
        XCTAssertEqual(bounds.center.longitude, 4.85, accuracy: 0.0001)
        XCTAssertGreaterThan(bounds.span.latitudeDelta, 0.02)
    }

    func testEmptyInputProducesNoClusters() {
        XCTAssertTrue(MapClusterer.clusters(for: [], in: region(span: 0.05)).isEmpty)
    }
}
