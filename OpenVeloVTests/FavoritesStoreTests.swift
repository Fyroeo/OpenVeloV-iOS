import XCTest
@testable import OpenVeloV

@MainActor
final class FavoritesStoreTests: XCTestCase {

    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testStartsEmpty() {
        let store = FavoritesStore(defaults: makeDefaults())
        XCTAssertTrue(store.stationNumbers.isEmpty)
        XCTAssertFalse(store.contains(3015))
    }

    func testToggleWithoutAnAccountStillPersists() async {
        let defaults = makeDefaults()
        let store = FavoritesStore(defaults: defaults)

        await store.toggle(3015, client: nil, accountId: nil)
        XCTAssertTrue(store.contains(3015))

        let reloaded = FavoritesStore(defaults: defaults)
        XCTAssertTrue(reloaded.contains(3015))
    }

    func testToggleTwiceRemoves() async {
        let store = FavoritesStore(defaults: makeDefaults())
        await store.toggle(3015, client: nil, accountId: nil)
        await store.toggle(3015, client: nil, accountId: nil)
        XCTAssertFalse(store.contains(3015))
    }

    func testContainsIsFalseForNil() {
        let store = FavoritesStore(defaults: makeDefaults())
        XCTAssertFalse(store.contains(nil))
    }

    func testPersistedNumbersSurviveReload() async {
        let defaults = makeDefaults()
        let store = FavoritesStore(defaults: defaults)
        await store.toggle(1, client: nil, accountId: nil)
        await store.toggle(2, client: nil, accountId: nil)
        await store.toggle(3, client: nil, accountId: nil)
        await store.toggle(2, client: nil, accountId: nil)

        let reloaded = FavoritesStore(defaults: defaults)
        XCTAssertEqual(reloaded.stationNumbers, [1, 3])
    }
}
