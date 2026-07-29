import Foundation

enum DeepLink {
    static let scheme = "openvelov"

    static var nearestBike: URL { URL(string: "\(scheme)://nearest")! }

    static var nearestDock: URL { URL(string: "\(scheme)://dock")! }

    static var search: URL { URL(string: "\(scheme)://search")! }

    static func station(number: String) -> URL {
        URL(string: "\(scheme)://station/\(number)")!
    }

    enum Action: Equatable {
        case nearestBike
        case nearestDock
        case search
        case station(number: String)
    }

    static func action(for url: URL) -> Action? {
        guard url.scheme == scheme else { return nil }
        switch url.host() {
        case "nearest": return .nearestBike
        case "dock": return .nearestDock
        case "search": return .search
        case "station":
            let number = url.pathComponents.filter { $0 != "/" }.first
            return number.map { .station(number: $0) }
        default: return nil
        }
    }
}
