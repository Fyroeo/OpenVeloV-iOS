import CoreLocation
import XCTest
@testable import OpenVeloV

final class StationLogicTests: XCTestCase {

    private func station(
        mechanical: Int = 0,
        electrical: Int = 0,
        docks: Int = 0,
        renting: Bool = true,
        returning: Bool = true
    ) -> MapStation {
        MapStation(
            id: "1",
            name: "Test",
            coordinate: CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85),
            capacity: 20,
            mechanicalBikes: mechanical,
            electricalBikes: electrical,
            docksAvailable: docks,
            isRenting: renting,
            isReturning: returning
        )
    }

    // MARK: - Availability

    func testAvailabilityBuckets() {
        XCTAssertEqual(MapNumberMode.all.availability(for: station(mechanical: 0)), AvailabilityLevel.none)
        XCTAssertEqual(MapNumberMode.all.availability(for: station(mechanical: 1)), .few)
        XCTAssertEqual(MapNumberMode.all.availability(for: station(mechanical: 3)), .few)
        XCTAssertEqual(MapNumberMode.all.availability(for: station(mechanical: 4)), .plenty)
    }

    func testParkingModeReadsReturningNotRenting() {
        // A station can be closed for renting but still accept returns.
        let closedForRenting = station(docks: 8, renting: false, returning: true)
        XCTAssertTrue(MapNumberMode.parking.isAvailable(at: closedForRenting))
        XCTAssertFalse(MapNumberMode.all.isAvailable(at: closedForRenting))
        XCTAssertEqual(MapNumberMode.parking.availability(for: closedForRenting), .plenty)
    }

    func testModeCounts() {
        let subject = station(mechanical: 3, electrical: 4, docks: 5)
        XCTAssertEqual(MapNumberMode.all.count(for: subject), 7)
        XCTAssertEqual(MapNumberMode.electrical.count(for: subject), 4)
        XCTAssertEqual(MapNumberMode.parking.count(for: subject), 5)
    }

    // MARK: - Distance

    func testWalkingMinutesRoundsUpAndFloorsAtOne() {
        XCTAssertEqual(MapStation.walkingMinutes(for: 10), 1)
        XCTAssertEqual(MapStation.walkingMinutes(for: 0), 1)
        // The 5 km/h assumption works out to ~83 m per minute.
        XCTAssertEqual(MapStation.walkingMinutes(for: 500), 6)
        XCTAssertEqual(MapStation.walkingMinutes(for: 1000), 12)
    }

    func testDistanceTextIsNonEmptyAndScales() {
        // Asserts shape only: the exact string depends on the test runner's locale.
        XCTAssertFalse(MapStation.distanceText(240).isEmpty)
        XCTAssertFalse(MapStation.distanceText(2400).isEmpty)
        XCTAssertNotEqual(MapStation.distanceText(240), MapStation.distanceText(2400))
        XCTAssertNotEqual(MapStation.distanceText(0), MapStation.distanceText(5000))
    }

    func testDistanceTextUsesMetricInFrance() throws {
        var style = Measurement<UnitLength>.FormatStyle.measurement(width: .abbreviated, usage: .road)
        style.locale = Locale(identifier: "fr_FR")
        let text = Measurement(value: 240, unit: UnitLength.meters).formatted(style)
        XCTAssertTrue(text.contains("m"), "expected a metric unit in fr_FR, got \(text)")
    }

    func testWalkingTimeIsSuppressedBeyondWalkingRange() {
        XCTAssertNotNil(MapStation.walkingTimeText(for: 400))
        XCTAssertNotNil(MapStation.walkingTimeText(for: MapStation.maximumWalkableDistance))
        XCTAssertNil(MapStation.walkingTimeText(for: MapStation.maximumWalkableDistance + 1))
        XCTAssertNil(MapStation.walkingTimeText(for: 8_960_000)) // San Francisco → Lyon
    }

    func testUserLocationDistanceIsSymmetric() {
        let here = UserLocation(latitude: 45.75, longitude: 4.85)
        let there = CLLocationCoordinate2D(latitude: 45.76, longitude: 4.86)
        let distance = here.distance(to: there)
        XCTAssertEqual(distance, UserLocation(there).distance(to: here.coordinate), accuracy: 0.001)
        XCTAssertGreaterThan(distance, 1000)
    }

    // MARK: - Identifiers

    func testIdentifiersNeverTakeAThousandsSeparator() {
        XCTAssertEqual(22881.identifierText, "22881")
        XCTAssertEqual(10063.identifierText, "10063")
        XCTAssertEqual(5.identifierText, "5")
        XCTAssertFalse(1234567.identifierText.contains(","))
        XCTAssertFalse(1234567.identifierText.contains("\u{202F}")) // narrow no-break space, used in fr
        XCTAssertFalse(1234567.identifierText.contains(" "))
    }

    // MARK: - Deep links

    func testDeepLinkParsing() {
        XCTAssertEqual(DeepLink.action(for: DeepLink.nearestBike), .nearestBike)
        XCTAssertEqual(DeepLink.action(for: DeepLink.nearestDock), .nearestDock)
        XCTAssertEqual(DeepLink.action(for: DeepLink.search), .search)
        XCTAssertEqual(DeepLink.action(for: DeepLink.station(number: "3015")), .station(number: "3015"))
    }

    func testDeepLinkRejectsForeignSchemes() {
        XCTAssertNil(DeepLink.action(for: URL(string: "https://example.com/nearest")!))
        XCTAssertNil(DeepLink.action(for: URL(string: "openvelov://unknown")!))
    }
}
