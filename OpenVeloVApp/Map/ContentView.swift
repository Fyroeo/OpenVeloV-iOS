import MapKit
import SwiftUI
import UIKit
import VLSKit

struct ContentView: View {
    // State is internal, not private: the map/controls live in ContentView+Overlays.swift and
    // the actions in ContentView+Actions.swift, extensions that can only reach internal members.
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("mapNumberMode") var numberModeRaw = MapNumberMode.all.rawValue
    @StateObject var locationManager = LocationManager()
    @StateObject var stationsVM = StationsViewModel()
    @StateObject var settings = AppSettings()
    @StateObject var rideLocationService = RideLocationService()
    @StateObject var favorites: FavoritesStore
    @StateObject var authVM: AuthViewModel
    @StateObject var tripVM: TripViewModel
    @StateObject var bookingVM: BookingViewModel
    /// Held here rather than built per sheet so the anonymous token is fetched once and reused.
    private let bikeDetailClient = BikeDetailClient(environment: AppSecrets.environment)

    static var isBikeDetailConfigured: Bool { AppSecrets.isConfigured }

    private static let lyonRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State var cameraPosition: MapCameraPosition = .region(lyonRegion)
    @State var visibleRegion: MKCoordinateRegion = lyonRegion
    @State var selectedStation: MapStation?
    @State var didCenterOnUser = false
    @State var showProfile = false
    @State var showTrips = false
    @State var showFavorites = false
    @State var showSubscription = false
    @State var showRequestExtraTime = false
    @State var showSearch = false
    @State var showSettings = false
    @State var showImpact = false
    @State var showNews = false
    @State var showBikeLookup = false
    @State var dockSuggestion: MapStation?
    @State var showBookingUnlock = false
    @State var isUnlockingBooking = false
    @State var bookingUnlockResult: BikeActionSheet.ActionResult?

    var numberMode: MapNumberMode {
        MapNumberMode(rawValue: numberModeRaw) ?? .all
    }

    /// The view models reference each other, so they have to be built in order here rather than
    /// as property defaults.
    init() {
        let favoritesStore = FavoritesStore()
        let appSettings = AppSettings()
        let locationService = RideLocationService()
        let auth = AuthViewModel(favorites: favoritesStore)
        let trip = TripViewModel(authViewModel: auth, settings: appSettings, locationService: locationService)
        let booking = BookingViewModel(
            authViewModel: auth,
            tripViewModel: trip,
            settings: appSettings,
            locationService: locationService
        )
        trip.onTripStarted = { [weak booking] in await booking?.handleTripStarted() }
        _favorites = StateObject(wrappedValue: favoritesStore)
        _settings = StateObject(wrappedValue: appSettings)
        _rideLocationService = StateObject(wrappedValue: locationService)
        _authVM = StateObject(wrappedValue: auth)
        _tripVM = StateObject(wrappedValue: trip)
        _bookingVM = StateObject(wrappedValue: booking)
    }

    var body: some View {
        ZStack(alignment: .top) {
            map
                .overlay(alignment: .bottom) { bottomControls }

            topControls
        }
        .sheet(item: $selectedStation) { station in
            StationDetailView(
                station: station,
                bikeDetailClient: bikeDetailClient,
                authVM: authVM,
                tripVM: tripVM,
                bookingVM: bookingVM,
                stationsVM: stationsVM,
                favorites: favorites,
                userLocation: locationManager.userLocation,
                onRequestSignIn: presentSignIn
            )
            // Without this the map is visible but not pannable behind the sheet at the medium detent.
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authVM: authVM, onSignOut: {
                tripVM.reset()
                bookingVM.reset()
                stationsVM.clearBonusStations()
            })
        }
        .sheet(isPresented: $showTrips) {
            TripsView(authVM: authVM, stationsVM: stationsVM)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesView(
                favorites: favorites,
                stationsVM: stationsVM,
                authVM: authVM,
                userLocation: locationManager.userLocation,
                onSelect: focus(on:)
            )
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionDetailView(authVM: authVM)
        }
        .sheet(isPresented: $showSearch) {
            StationSearchView(
                stationsVM: stationsVM,
                favorites: favorites,
                userLocation: locationManager.userLocation,
                onSelect: focus(on:)
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, locationManager: locationManager)
        }
        .sheet(isPresented: $showImpact) {
            ImpactView(authVM: authVM)
        }
        .sheet(isPresented: $showNews) {
            NewsView(authVM: authVM)
        }
        .sheet(isPresented: $showBikeLookup) {
            BikeLookupView(bikeDetailClient: bikeDetailClient, authVM: authVM, stationsVM: stationsVM)
        }
        .sheet(item: $tripVM.tripToRate) { trip in
            RateBikeView(trip: trip, authVM: authVM, didUploadRoute: tripVM.didUploadRouteForLastTrip)
                .onDisappear { tripVM.acknowledgeRouteUpload() }
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
        .sheet(item: $dockSuggestion) { station in
            NearestDockSheet(
                station: station,
                userLocation: locationManager.userLocation,
                onDirections: {
                    dockSuggestion = nil
                    openDirections(to: station)
                },
                onShowOnMap: {
                    dockSuggestion = nil
                    focus(on: station)
                }
            )
        }
        .fullScreenCover(isPresented: Binding(get: { !hasCompletedOnboarding }, set: { hasCompletedOnboarding = !$0 })) {
            OnboardingView(locationManager: locationManager) {
                hasCompletedOnboarding = true
            }
        }
        .task {
            // Onboarding asks for these itself, so only prompt here on subsequent launches.
            if hasCompletedOnboarding {
                locationManager.requestAuthorization()
                NotificationManager.requestAuthorizationIfNeeded()
            }
            authVM.onAccountLoaded = { [weak stationsVM, weak authVM] _ in
                guard let stationsVM, let authVM else { return }
                await stationsVM.loadBonusStations(client: authVM.client)
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
        .onOpenURL { url in
            handle(deepLink: url)
        }
        .onChange(of: locationManager.userLocation) { _, newValue in
            guard newValue != nil, !didCenterOnUser else { return }
            didCenterOnUser = true
            centerOnUser()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // `resumeAutoRefresh` already refreshes at once when the cached counts are
                // older than the interval, so asking again here would double the request.
                stationsVM.resumeAutoRefresh()
                Task {
                    await tripVM.refreshActiveTrip()
                    await bookingVM.refreshActiveBooking()
                }
            case .background:
                stationsVM.stopAutoRefresh()
                BackgroundRefreshManager.scheduleNextRefresh()
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
