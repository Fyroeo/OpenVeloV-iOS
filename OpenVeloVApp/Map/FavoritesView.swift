import SwiftUI
import VLSKit

struct FavoritesView: View {
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var stationsVM: StationsViewModel
    @ObservedObject var authVM: AuthViewModel
    let userLocation: UserLocation?
    let onSelect: (MapStation) -> Void

    @Environment(\.dismiss) private var dismiss

    private var stations: [MapStation] {
        let matched = favorites.stationNumbers.compactMap { stationsVM.station(forNumber: $0) }
        guard let userLocation else { return matched.sorted { $0.name < $1.name } }
        return matched.sorted { userLocation.distance(to: $0.coordinate) < userLocation.distance(to: $1.coordinate) }
    }

    private var unmatchedNumbers: [Int] {
        favorites.stationNumbers
            .filter { stationsVM.station(forNumber: $0) == nil }
            .sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.stationNumbers.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text("Tap the star on any station to save it here for quick access.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(stations) { station in
                                Button {
                                    onSelect(station)
                                    dismiss()
                                } label: {
                                    StationListRow(
                                        station: station,
                                        userLocation: userLocation,
                                        hasBonus: stationsVM.hasBonus(stationNumber: station.number)
                                    )
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        unstar(station.number)
                                    } label: {
                                        Label("Remove", systemImage: "star.slash")
                                    }
                                }
                            }
                        }

                        if !unmatchedNumbers.isEmpty {
                            Section {
                                ForEach(unmatchedNumbers, id: \.self) { number in
                                    HStack {
                                        Label("Station \(number.identifierText)", systemImage: "questionmark.circle")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Button("Remove") { unstar(number) }
                                            .buttonStyle(.borderless)
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            } header: {
                                Text("Not in the live feed")
                            } footer: {
                                Text("These stations aren't reporting right now. They may have been removed from the network.")
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
            }
        }
    }

    private func unstar(_ number: Int?) {
        guard let number else { return }
        Task { await favorites.toggle(number, client: authVM.isAuthenticated ? authVM.client : nil, accountId: authVM.accountId) }
    }
}
