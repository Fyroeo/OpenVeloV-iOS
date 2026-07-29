import MapKit
import SwiftUI
import UIKit

/// Map navigation, deep-link routing, and the booking-unlock flow. Split from
/// ContentView.swift.
extension ContentView {
    /// Handles `openvelov://` links, which come from the home-screen widget and the Control Center
    /// controls.
    func handle(deepLink url: URL) {
        guard let action = DeepLink.action(for: url) else { return }
        Task {
            // A deep link can cold-launch the app, so the station feed may not have loaded yet.
            if !stationsVM.hasLoaded {
                await stationsVM.refresh()
            }
            switch action {
            case .nearestBike:
                await focusNearest { $0.isRenting && $0.totalBikes > 0 }
            case .nearestDock:
                await focusNearest { $0.isReturning && $0.docksAvailable > 0 }
            case .search:
                showSearch = true
            case .station(let number):
                if let station = Int(number).flatMap({ stationsVM.station(forNumber: $0) }) {
                    focus(on: station)
                } else {
                    showSearch = true
                }
            }
        }
    }

    func focusNearest(where isEligible: @escaping (MapStation) -> Bool) async {
        let location = await locationManager.firstLocation()
        if let station = stationsVM.nearest(to: location, where: isEligible) {
            focus(on: station)
        } else {
            showSearch = true
        }
    }

    func presentSignIn() {
        selectedStation = nil
        showProfile = true
        Task { await authVM.startLogin() }
    }

    func focus(on station: MapStation) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(center: station.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006))
            )
        }
        selectedStation = station
    }

    func zoom(into cluster: MapCluster) {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(cluster.boundingRegion)
        }
    }

    func performBookingUnlock() {
        bookingUnlockResult = nil
        isUnlockingBooking = true
        Task {
            let result = await bookingVM.unlockActiveBooking()
            isUnlockingBooking = false
            UINotificationFeedbackGenerator().notificationOccurred(result.success ? .success : .error)
            bookingUnlockResult = BikeActionSheet.ActionResult(
                succeeded: result.success,
                title: result.success ? String(localized: "Bike Unlocked") : String(localized: "Unlock Failed"),
                message: result.message
            )
        }
    }

    func openDirections(to station: MapStation) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: station.coordinate))
        item.name = station.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    func goToNearestAvailable() {
        guard locationManager.userLocation != nil else {
            centerOnUser()
            return
        }
        guard let nearest = stationsVM.nearest(to: locationManager.userLocation, where: isUsable) else { return }
        focus(on: nearest)
    }

    func centerOnUser() {
        guard let userLocation = locationManager.userLocation else { return }
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(center: userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            )
        }
    }

    func suggestNearestDock() {
        // No fallback to an arbitrary station: without a fix, feed order has nothing to do
        // with proximity, and presenting it as "nearest" mid-ride would send a rider the
        // wrong way.
        guard let nearest = stationsVM.nearest(to: locationManager.userLocation, where: {
            $0.isReturning && $0.docksAvailable > 0
        }) else {
            showSearch = true
            return
        }
        dockSuggestion = nearest
    }
}
