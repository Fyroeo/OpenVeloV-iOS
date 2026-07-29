import CoreLocation
import SwiftUI
import VLSKit

struct TripsView: View {
    @ObservedObject var authVM: AuthViewModel
    /// Resolves station numbers to names and coordinates, which the trip feed often leaves out.
    @ObservedObject var stationsVM: StationsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var trips: [Trip] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var stationNames: [Int: String] {
        stationsVM.stationsByNumber.mapValues(\.name)
    }

    private var stationCoordinates: [Int: CLLocationCoordinate2D] {
        stationsVM.stationsByNumber.mapValues(\.coordinate)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && trips.isEmpty {
                    ProgressView("Loading rides…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Load Rides", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    }
                } else if trips.isEmpty {
                    ContentUnavailableView("No Rides Yet", systemImage: "bicycle", description: Text("Your ride history will show up here."))
                } else {
                    List {
                        Section {
                            RideStatsCard(trips: trips)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        Section {
                            ForEach(sortedTrips) { trip in
                                NavigationLink {
                                    TripDetailView(trip: trip, stationNames: stationNames, stationCoordinates: stationCoordinates, authVM: authVM)
                                } label: {
                                    TripRow(trip: trip, stationNames: stationNames)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Rides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await loadTrips() }
        .refreshable { await loadTrips() }
    }

    private var sortedTrips: [Trip] {
        trips.sorted { ($0.startDateTime ?? .distantPast) > ($1.startDateTime ?? .distantPast) }
    }

    private func loadTrips() async {
        guard let accountId = authVM.accountId else {
            errorMessage = String(localized: "Sign in to see your rides.")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            trips = try await authVM.client.trips.trips(accountId: accountId)
            errorMessage = nil
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .trips)
        }
    }
}
