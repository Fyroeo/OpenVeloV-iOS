import CoreLocation
import XCTest
@testable import OpenVeloV

final class RoutePlaybackTests: XCTestCase {

    private let line = [
        CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85),
        CLLocationCoordinate2D(latitude: 45.76, longitude: 4.85),
        CLLocationCoordinate2D(latitude: 45.77, longitude: 4.85),
    ]

    func testEndpointsMapToStartAndEnd() {
        let playback = RoutePlayback(line)
        let start = playback.point(at: 0)
        let end = playback.point(at: 1)
        XCTAssertEqual(start?.latitude ?? 0, 45.75, accuracy: 1e-6)
        XCTAssertEqual(end?.latitude ?? 0, 45.77, accuracy: 1e-6)
    }

    func testMidpointIsHalfway() {
        let playback = RoutePlayback(line)
        let mid = playback.point(at: 0.5)
        // Even spacing north, so halfway distance is the middle vertex.
        XCTAssertEqual(mid?.latitude ?? 0, 45.76, accuracy: 1e-4)
    }

    func testTraveledGrowsWithProgress() {
        let playback = RoutePlayback(line)
        XCTAssertLessThan(playback.traveled(upTo: 0.25).count, playback.traveled(upTo: 1).count)
        XCTAssertEqual(playback.traveled(upTo: 1).last?.latitude ?? 0, 45.77, accuracy: 1e-6)
    }

    func testSinglePointIsSafe() {
        let playback = RoutePlayback([CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85)])
        XCTAssertEqual(playback.totalDistance, 0)
        XCTAssertNotNil(playback.point(at: 0.5))
    }

    func testEmptyIsSafe() {
        let playback = RoutePlayback([])
        XCTAssertNil(playback.point(at: 0.5))
        XCTAssertNil(playback.boundingRegion)
    }
}
