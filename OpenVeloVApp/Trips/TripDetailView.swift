import MapKit
import SwiftUI
import VLSKit

/// This view shows the full detail for 1 ride. The user opens it by tapping a row in `TripsView`.
struct TripDetailView: View {
    let trip: Trip
    let stationNames: [Int: String]
    let stationCoordinates: [Int: CLLocationCoordinate2D]
    @ObservedObject var authVM: AuthViewModel

    @State private var showRating = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    /// The rider's recorded GPS trace for this ride, if the server has one.
    /// `TripService.route`'s shape is unverified, so a decode failure leaves the route
    /// empty while the start and end pins still show.
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []

    private var canRate: Bool {
        trip.id != nil && trip.bikeNumber != nil
            && (trip.status == .finished || trip.status == .autoFinished)
            && trip.isRated != true
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        trip.startStation.flatMap { stationCoordinates[$0] }
    }

    private var endCoordinate: CLLocationCoordinate2D? {
        trip.endStation.flatMap { stationCoordinates[$0] }
    }

    /// This is `true` when the start and end stations are the same, or the end station
    /// is unknown. The map uses this value to avoid 2 pins at the same place.
    private var endIsSameAsStart: Bool {
        guard let startCoordinate, let endCoordinate else { return false }
        return startCoordinate.latitude == endCoordinate.latitude && startCoordinate.longitude == endCoordinate.longitude
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: trip.bikeType == .electrical ? "bolt.fill" : "bicycle")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(trip.bikeType == .electrical ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 2) {
                        if let bikeNumber = trip.bikeNumber {
                            Text("Bike #\(bikeNumber)")
                                .font(.headline)
                        } else {
                            Text("Ride")
                                .font(.headline)
                        }
                        Text(trip.bikeType == .electrical ? "Electric" : "Mechanical")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let status = trip.status {
                        Text(status.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.tintColor)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Route") {
                LabeledContent("From", value: stationName(forNumber: trip.startStation, in: stationNames) ?? "Unknown")
                LabeledContent("To", value: stationName(forNumber: trip.endStation, in: stationNames) ?? "Unknown")

                if startCoordinate != nil || endCoordinate != nil {
                    Map(position: $cameraPosition) {
                        if routeCoordinates.count > 1 {
                            MapPolyline(coordinates: routeCoordinates)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }
                        if let startCoordinate {
                            Marker("Start", systemImage: "flag.fill", coordinate: startCoordinate)
                                .tint(.green)
                        }
                        if let endCoordinate, !endIsSameAsStart {
                            Marker("End", systemImage: "flag.checkered", coordinate: endCoordinate)
                                .tint(.red)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    .onAppear(perform: fitCamera)
                    .task { await loadRoute() }
                }
            }

            Section("Timing") {
                if let start = trip.startDateTime {
                    LabeledContent("Started", value: start.formatted(date: .abbreviated, time: .shortened))
                }
                if let end = trip.endDateTime {
                    LabeledContent("Ended", value: end.formatted(date: .abbreviated, time: .shortened))
                }
                if let duration = formattedDuration(for: trip) {
                    LabeledContent("Duration", value: duration)
                }
            }

            if hasBillingInfo {
                Section("Billing") {
                    if let price = trip.price {
                        LabeledContent("Price", value: currencyText(price))
                    }
                    if let reducedPrice = trip.reducedPrice, reducedPrice != 0 {
                        LabeledContent("Reduced price", value: currencyText(reducedPrice))
                    }
                    if let discount = trip.discount, discount != 0 {
                        LabeledContent("Discount", value: currencyText(discount))
                    }
                    if let rewardsEarned = trip.rewardsEarned, rewardsEarned != 0 {
                        LabeledContent("Rewards earned", value: "\(rewardsEarned)")
                    }
                    if let rewardsSpent = trip.rewardsSpent, rewardsSpent != 0 {
                        LabeledContent("Rewards spent", value: "\(rewardsSpent)")
                    }
                }
            }

            if trip.litigious == true || trip.isSpecial == true {
                Section {
                    if trip.litigious == true {
                        Label("Flagged as litigious", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if trip.isSpecial == true {
                        Label("Special trip", systemImage: "star")
                            .foregroundStyle(.orange)
                    }
                }
            }

            if canRate {
                Section {
                    Button("Rate This Ride") { showRating = true }
                }
            }

            Section("Reference") {
                if let movementRef = trip.movementRef {
                    LabeledContent("Movement ref", value: movementRef)
                }
                if let subscriptionRef = trip.subscriptionRef {
                    LabeledContent("Subscription ref", value: subscriptionRef)
                }
            }
        }
        .navigationTitle("Ride Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRating) {
            RateBikeView(trip: trip, authVM: authVM)
        }
    }

    private func loadRoute() async {
        guard let accountId = authVM.accountId, let tripId = trip.id else { return }
        guard let geoJSON = try? await authVM.client.trips.route(accountId: accountId, tripId: tripId) else { return }
        let coordinates = Self.lineStringCoordinates(from: geoJSON)
        guard coordinates.count > 1 else { return }
        routeCoordinates = coordinates
        fitCamera()
    }

    /// A GeoJSON `LineString` coordinate is a `[longitude, latitude]` pair. It can have a
    /// third elevation value. The order is easy to reverse by mistake.
    /// This method returns an empty route for any other shape. It does not guess values.
    private static func lineStringCoordinates(from geoJSON: GeoJSON) -> [CLLocationCoordinate2D] {
        guard geoJSON.type == "LineString", case .array(let points)? = geoJSON.coordinates else { return [] }
        return points.compactMap { point -> CLLocationCoordinate2D? in
            guard case .array(let components) = point, components.count >= 2,
                  case .number(let longitude) = components[0],
                  case .number(let latitude) = components[1] else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private func fitCamera() {
        let coordinates = [startCoordinate, endIsSameAsStart ? nil : endCoordinate].compactMap { $0 } + routeCoordinates
        guard !coordinates.isEmpty else { return }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.8, 0.006),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.8, 0.006)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private var hasBillingInfo: Bool {
        trip.price != nil || trip.reducedPrice != nil || trip.discount != nil
            || trip.rewardsEarned != nil || trip.rewardsSpent != nil
    }
}
