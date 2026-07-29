import MapKit
import SwiftUI

/// The map and the controls layered over it. Split from ContentView.swift, which keeps the
/// state, the sheet wiring, and the lifecycle.
extension ContentView {
    var clusters: [MapCluster] {
        MapClusterer.clusters(for: stationsVM.stations, in: visibleRegion)
    }

    // MARK: - Map

    var map: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(clusters) { cluster in
                Annotation(cluster.single?.name ?? "", coordinate: cluster.coordinate) {
                    if let station = cluster.single {
                        StationMarkerView(
                            station: station,
                            numberMode: numberMode,
                            isFavorite: favorites.contains(station.number),
                            hasBonus: stationsVM.hasBonus(stationNumber: station.number),
                            isSelected: selectedStation?.id == station.id
                        )
                        .onTapGesture { focus(on: station) }
                    } else {
                        StationClusterMarkerView(
                            cluster: cluster,
                            numberMode: numberMode,
                            containsFavorite: cluster.stations.contains { favorites.contains($0.number) }
                        )
                        .onTapGesture { zoom(into: cluster) }
                    }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard)
        .mapControls { MapCompass() }
        .ignoresSafeArea(edges: .bottom)
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
    }

    // MARK: - Overlays

    var bottomControls: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    hamburgerMenu
                    legend
                }
                Spacer()
                mapButtons
            }

            if let activeBooking = bookingVM.activeBooking {
                BookingBanner(
                    booking: activeBooking,
                    stationName: stationsVM.name(forNumber: activeBooking.stationNumber),
                    onDirections: {
                        if let station = stationsVM.station(forNumber: activeBooking.stationNumber) {
                            openDirections(to: station)
                        }
                    },
                    onUnlock: {
                        showBookingUnlock = true
                        performBookingUnlock()
                    }
                )
            }

            if let activeTrip = tripVM.activeTrip {
                ActiveTripBanner(
                    trip: activeTrip,
                    onNearestDock: suggestNearestDock,
                    onExtraTime: { showRequestExtraTime = true }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    var topControls: some View {
        VStack(spacing: 8) {
            searchBar
            modeControl

            if let errorMessage = stationsVM.errorMessage {
                Label(errorMessage, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            } else if let staleness = stalenessText {
                Label(staleness, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var searchBar: some View {
        Button {
            showSearch = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Search stations")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search stations")
    }

    private var modeControl: some View {
        Picker("Map shows", selection: Binding(
            get: { numberMode },
            set: { newMode in withAnimation(.snappy) { numberModeRaw = newMode.rawValue } }
        )) {
            ForEach(MapNumberMode.allCases) { mode in
                Text(mode.shortLabel).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(AvailabilityLevel.allCases, id: \.self) { level in
                HStack(spacing: 4) {
                    Circle().fill(level.color).frame(width: 8, height: 8)
                    Text(level.label)
                }
            }
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend: green plenty, orange few, red none")
    }

    private var hamburgerMenu: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label("Account", systemImage: authVM.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
            }
            Button {
                showFavorites = true
            } label: {
                Label("Favorites", systemImage: "star")
            }
            if authVM.isAuthenticated {
                Button {
                    showTrips = true
                } label: {
                    Label("My Rides", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    showImpact = true
                } label: {
                    Label("Your Impact", systemImage: "leaf")
                }
                Button {
                    showSubscription = true
                } label: {
                    Label("My Subscription", systemImage: "creditcard")
                }
            }
            Divider()
            Button {
                showBikeLookup = true
            } label: {
                Label("Find a Bike", systemImage: "number.circle")
            }
            Button {
                showNews = true
            } label: {
                Label("News & Alerts", systemImage: "newspaper")
            }
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
#if DEBUG
            Divider()
            Button {
                tripVM.togglePreviewRide()
            } label: {
                Label(tripVM.activeTrip == nil ? "Preview Ride Card" : "Stop Preview Ride", systemImage: "wrench.and.screwdriver")
            }
            Button {
                bookingVM.togglePreviewBooking()
            } label: {
                Label(bookingVM.activeBooking == nil ? "Preview Booking Card" : "Stop Preview Booking", systemImage: "wrench.and.screwdriver")
            }
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Replay Onboarding", systemImage: "wrench.and.screwdriver")
            }
#endif
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title2)
                .foregroundStyle(Color.primary)
                .padding(10)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Menu")
    }

    private var mapButtons: some View {
        VStack(spacing: 12) {
            Button {
                goToNearestAvailable()
            } label: {
                Image(systemName: numberMode.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor)
                            .padding(3)
                            .background(.thinMaterial, in: Circle())
                    }
            }
            .accessibilityLabel("Jump to nearest \(numberMode.unitLabel)")

            Button {
                centerOnUser()
            } label: {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("Center on my location")
        }
    }

    private var stalenessText: String? {
        guard let lastUpdated = stationsVM.lastUpdated else { return nil }
        let age = Date().timeIntervalSince(lastUpdated)
        guard age > 90 else { return nil }
        return String(localized: "Counts last updated \(Int(age / 60)) min ago")
    }

    func isUsable(_ station: MapStation) -> Bool {
        numberMode.isAvailable(at: station) && numberMode.count(for: station) > 0
    }
}
