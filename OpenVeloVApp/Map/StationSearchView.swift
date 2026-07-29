import SwiftUI

struct StationSearchView: View {
    @ObservedObject var stationsVM: StationsViewModel
    @ObservedObject var favorites: FavoritesStore
    let userLocation: UserLocation?
    let onSelect: (MapStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable, Identifiable {
        case all
        case bikes
        case electric
        case docks
        case favorites

        var id: Self { self }

        var label: String {
            switch self {
            case .all: return String(localized: "All")
            case .bikes: return String(localized: "Bikes")
            case .electric: return String(localized: "E-bikes")
            case .docks: return String(localized: "Docks")
            case .favorites: return String(localized: "Starred")
            }
        }
    }

    private var results: [MapStation] {
        let base = stationsVM.search(query, near: userLocation, limit: 200)
        switch filter {
        case .all: return base
        case .bikes: return base.filter { $0.isRenting && $0.totalBikes > 0 }
        case .electric: return base.filter { $0.isRenting && $0.electricalBikes > 0 }
        case .docks: return base.filter { $0.isReturning && $0.docksAvailable > 0 }
        case .favorites: return base.filter { favorites.contains($0.number) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !stationsVM.hasLoaded {
                    ProgressView("Loading stations…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(results) { station in
                                Button {
                                    onSelect(station)
                                    dismiss()
                                } label: {
                                    StationListRow(
                                        station: station,
                                        userLocation: userLocation,
                                        isFavorite: favorites.contains(station.number),
                                        hasBonus: stationsVM.hasBonus(stationNumber: station.number)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(sectionTitle)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Find a Station")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                filterBar
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Station name")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { option in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { filter = option }
                    } label: {
                        Text(option.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(filter == option ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(filter == option ? Color.accentColor : Color(.secondarySystemFill))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var sectionTitle: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(localized: "\(results.count) results", comment: "Search results count header")
        }
        return userLocation == nil ? String(localized: "All stations") : String(localized: "Nearest first")
    }

    @ViewBuilder
    private var emptyState: some View {
        if filter == .favorites {
            ContentUnavailableView(
                "No Starred Stations",
                systemImage: "star",
                description: Text("Tap the star on any station to save it here for quick access.")
            )
        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
            ContentUnavailableView(
                "Nothing Matches That Filter",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No station nearby currently has what you're filtering for.")
            )
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}
