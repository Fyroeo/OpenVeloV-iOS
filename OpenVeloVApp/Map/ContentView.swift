import MapKit
import SwiftUI
import UIKit
import VLSKit

/// The main screen of the app.
/// It shows a live map of Vélo'v stations from `StationsViewModel`.
/// It also shows the station detail sheet and the hamburger menu.
/// The menu opens the account, favorites, trips, and subscription screens.
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stationsVM = StationsViewModel()
    @StateObject private var authVM: AuthViewModel
    @StateObject private var tripVM: TripViewModel
    @StateObject private var bookingVM: BookingViewModel
    /// The app creates this client one time and reuses it.
    /// This caches the anonymous token across station detail views.
    /// Without reuse, the app would fetch a new token every time a sheet opens.
    ///
    /// VLSKit ships no default for `webClientCode`/`webClientKey`; see `VLSEnvironment`'s
    /// doc comment for why. This repository does not supply a real value either, since
    /// it is public. Without one, per-bike detail (`BikeDetailClient`) fails; the rest of
    /// the app works normally. Supply your own value locally to enable that feature.
    private let bikeDetailClient = BikeDetailClient(
        environment: VLSEnvironment(
            webClientCode: "",
            webClientKey: ""
        )
    )

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85), // Lyon
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var selectedStation: MapStation?
    @State private var didCenterOnUser = false
    @State private var showProfile = false
    @State private var showTrips = false
    @State private var showFavorites = false
    @State private var showSubscription = false
    @State private var showRequestExtraTime = false
    @State private var numberMode: MapNumberMode = .all
    // Direct-unlock flow for booking. It copies the unlock UI in the station sheet.
    @State private var showBookingUnlock = false
    @State private var isUnlockingBooking = false
    @State private var bookingUnlockResult: BikeActionSheet.ActionResult?

    /// `TripViewModel` and `BookingViewModel` each depend on `AuthViewModel`, and
    /// `BookingViewModel` also depends on `TripViewModel`, so they cannot use plain
    /// property-default initializers; this wires them together once, up front.
    init() {
        let auth = AuthViewModel()
        let trip = TripViewModel(authViewModel: auth)
        let booking = BookingViewModel(authViewModel: auth, tripViewModel: trip)
        trip.onTripStarted = { [weak booking] in await booking?.handleTripStarted() }
        _authVM = StateObject(wrappedValue: auth)
        _tripVM = StateObject(wrappedValue: trip)
        _bookingVM = StateObject(wrappedValue: booking)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(stationsVM.stations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationMarkerView(station: station, numberMode: numberMode)
                            .onTapGesture { selectedStation = station }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard)
            .mapControls { MapCompass() }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .bottom) {
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
                            stationName: stationName(forNumber: activeBooking.stationNumber),
                            onDirections: {
                                if let station = mapStation(forNumber: activeBooking.stationNumber) {
                                    directions(to: station)
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
                            onNearestDock: goToNearestDock,
                            onExtraTime: { showRequestExtraTime = true }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            topControls
        }
        .sheet(item: $selectedStation) { station in
            StationDetailView(station: station, bikeDetailClient: bikeDetailClient, authVM: authVM, tripVM: tripVM, bookingVM: bookingVM, stationsVM: stationsVM)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authVM: authVM, onSignOut: {
                tripVM.reset()
                bookingVM.reset()
            })
        }
        .sheet(isPresented: $showTrips) {
            TripsView(authVM: authVM)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesView(authVM: authVM, tripVM: tripVM, bookingVM: bookingVM, stationsVM: stationsVM, bikeDetailClient: bikeDetailClient)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionDetailView(authVM: authVM)
        }
        .sheet(item: $tripVM.tripToRate) { trip in
            RateBikeView(trip: trip, authVM: authVM)
        }
        .sheet(isPresented: $showRequestExtraTime) {
            RequestExtraTimeView(authVM: authVM, stations: stationsVM.stations, userLocation: locationManager.userLocation)
        }
        .sheet(isPresented: $showBookingUnlock) {
            BookingUnlockSheet(
                isUnlocking: isUnlockingBooking,
                result: bookingUnlockResult,
                onRetry: performBookingUnlock
            )
        }
        .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { hasCompletedOnboarding = !$0 })) {
            OnboardingView(locationManager: locationManager) {
                hasCompletedOnboarding = true
            }
        }
        .task {
            // Onboarding shows the first permission prompts. It explains the request first.
            // After onboarding, later launches ask directly, with no explanation.
            // Both calls do nothing if the user already made a decision.
            if hasCompletedOnboarding {
                locationManager.requestAuthorization()
                NotificationManager.requestAuthorizationIfNeeded()
            }
            await stationsVM.refresh()
            stationsVM.startAutoRefresh()
            await authVM.refreshAuthenticationState()
            await tripVM.refreshActiveTrip()
            await bookingVM.refreshActiveBooking()
        }
        .onDisappear {
            stationsVM.stopAutoRefresh()
        }
        .onChange(of: locationManager.userLocation) { _, newValue in
            guard newValue != nil, !didCenterOnUser else { return }
            didCenterOnUser = true
            centerOnUser()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await stationsVM.refresh()
                    await tripVM.refreshActiveTrip()
                    await bookingVM.refreshActiveBooking()
                }
            case .background:
                BackgroundRefreshManager.scheduleNextRefresh()
            default:
                break
            }
        }
    }

    private var topControls: some View {
        VStack(spacing: 8) {
            modeControl

            if let errorMessage = stationsVM.errorMessage, stationsVM.stations.isEmpty {
                Label(errorMessage, systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var modeControl: some View {
        HStack(spacing: 4) {
            ForEach(MapNumberMode.allCases) { mode in
                Button {
                    withAnimation(.snappy) { numberMode = mode }
                } label: {
                    Text(mode.shortLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(numberMode == mode ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if numberMode == mode {
                                Capsule().fill(Color.accentColor)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.label)
            }
        }
        .padding(4)
        .background(.thinMaterial, in: Capsule())
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
    }

    private var hamburgerMenu: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label("Account", systemImage: authVM.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
            }
            if authVM.isAuthenticated {
                Button {
                    showFavorites = true
                } label: {
                    Label("Favorites", systemImage: "star")
                }
                Button {
                    showTrips = true
                } label: {
                    Label("My Rides", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    showSubscription = true
                } label: {
                    Label("My Subscription", systemImage: "creditcard")
                }
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
            .accessibilityLabel("Jump to nearest available")

            Button {
                centerOnUser()
            } label: {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
        }
    }

    private func isUsable(_ station: MapStation) -> Bool {
        numberMode.isAvailable(at: station) && numberMode.count(for: station) > 0
    }

    // MARK: - Actions

    private func stationName(forNumber number: Int?) -> String? {
        mapStation(forNumber: number)?.name
    }

    private func mapStation(forNumber number: Int?) -> MapStation? {
        guard let number else { return nil }
        return stationsVM.stations.first { $0.id == String(number) }
    }

    private func flyTo(_ station: MapStation) {
        selectedStation = station
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: station.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008))
            )
        }
    }

    private func performBookingUnlock() {
        bookingUnlockResult = nil
        isUnlockingBooking = true
        Task {
            let result = await bookingVM.unlockActiveBooking()
            isUnlockingBooking = false
            UINotificationFeedbackGenerator().notificationOccurred(result.success ? .success : .error)
            bookingUnlockResult = BikeActionSheet.ActionResult(
                succeeded: result.success,
                title: result.success ? "Bike Unlocked" : "Unlock Failed",
                message: result.message
            )
        }
    }

    private func directions(to station: MapStation) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        item.name = station.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    /// Moves the map to and opens the closest station for the current mode.
    /// This needs the user's location.
    private func goToNearestAvailable() {
        guard let userLocation = locationManager.userLocation else {
            centerOnUser()
            return
        }
        let here = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let nearest = stationsVM.stations
            .filter { isUsable($0) }
            .min { lhs, rhs in
                here.distance(from: CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude))
                    < here.distance(from: CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude))
            }
        if let nearest {
            flyTo(nearest)
        }
    }

    private func centerOnUser() {
        guard let userLocation = locationManager.userLocation else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: userLocation, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )
        }
    }

    /// Opens from the active-ride card.
    /// It gives walking directions to the closest station that can accept a returned bike.
    /// A station can accept a returned bike only if it has a free dock.
    /// If the user's location is not available, this moves the map there instead.
    private func goToNearestDock() {
        let candidates = stationsVM.stations.filter { $0.isReturning && $0.docksAvailable > 0 }
        let nearest: MapStation?
        if let userLocation = locationManager.userLocation {
            let here = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            nearest = candidates.min { lhs, rhs in
                here.distance(from: CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude))
                    < here.distance(from: CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude))
            }
        } else {
            nearest = candidates.first
        }
        guard let nearest else { return }
        if locationManager.userLocation != nil {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: nearest.coordinate))
            item.name = nearest.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        } else {
            flyTo(nearest)
        }
    }
}

#Preview {
    ContentView()
}
