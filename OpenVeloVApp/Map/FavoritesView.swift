import SwiftUI
import VLSKit

/// The list of favorite stations. The user opens it from the hamburger menu.
/// This view matches the account's saved station numbers against the live station list.
/// This way, each row shows the current availability.
struct FavoritesView: View {
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var tripVM: TripViewModel
    @ObservedObject var bookingVM: BookingViewModel
    @ObservedObject var stationsVM: StationsViewModel
    let bikeDetailClient: BikeDetailClient

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStation: MapStation?

    private var favorites: [MapStation] {
        authVM.favoriteStationNumbers
            .compactMap { number in stationsVM.stations.first { $0.id == String(number) } }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text("Tap the star on any station to save it here for quick access.")
                    )
                } else {
                    List {
                        ForEach(favorites) { station in
                            Button {
                                selectedStation = station
                            } label: {
                                FavoriteRow(station: station)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            let toRemove = indexSet.map { favorites[$0] }
                            for station in toRemove {
                                if let number = Int(station.id) {
                                    Task { await authVM.toggleFavorite(stationNumber: number) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !favorites.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
        }
        .sheet(item: $selectedStation) { station in
            StationDetailView(station: station, bikeDetailClient: bikeDetailClient, authVM: authVM, tripVM: tripVM, bookingVM: bookingVM, stationsVM: stationsVM)
        }
    }
}

private struct FavoriteRow: View {
    let station: MapStation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.subheadline)
                .foregroundStyle(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label("\(station.mechanicalBikes)", systemImage: "bicycle")
                        .foregroundStyle(.red)
                    Label("\(station.electricalBikes)", systemImage: "bolt.fill")
                        .foregroundStyle(.green)
                    Label("\(station.docksAvailable)", systemImage: "parkingsign")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
