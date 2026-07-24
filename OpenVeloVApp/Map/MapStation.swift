import CoreLocation
import VLSKit

/// A station model for the map.
/// It merges GBFS `station_information` (name and location) with `station_status`
/// (live bike and dock counts). The merge matches records by station id.
struct MapStation: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let capacity: Int?
    let mechanicalBikes: Int
    let electricalBikes: Int
    let docksAvailable: Int
    let isRenting: Bool
    let isReturning: Bool

    var totalBikes: Int { mechanicalBikes + electricalBikes }

    static func == (lhs: MapStation, rhs: MapStation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init?(information: GBFSStationInformation, status: GBFSStationStatus?) {
        id = information.id
        name = information.name.first(where: { $0.language.hasPrefix("fr") })?.text
            ?? information.name.first?.text
            ?? "Station \(information.id)"
        coordinate = CLLocationCoordinate2D(latitude: information.latitude, longitude: information.longitude)
        capacity = information.capacity

        guard let status else {
            mechanicalBikes = 0
            electricalBikes = 0
            docksAvailable = 0
            isRenting = false
            isReturning = false
            return
        }
        mechanicalBikes = status.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .mechanical })?.count ?? 0
        electricalBikes = status.vehicleTypesAvailable.first(where: { $0.vehicleTypeID == .electrical })?.count ?? 0
        docksAvailable = status.numDocksAvailable
        isRenting = status.isRenting
        isReturning = status.isReturning
    }
}
