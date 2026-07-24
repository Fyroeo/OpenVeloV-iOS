import MapKit
import SwiftUI
import UIKit
import VLSKit

/// The detail sheet for a station. It opens when the user taps a station marker on the map.
struct StationDetailView: View {
    let station: MapStation
    let bikeDetailClient: BikeDetailClient
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var tripVM: TripViewModel
    @ObservedObject var bookingVM: BookingViewModel
    @ObservedObject var stationsVM: StationsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var bikes: [Bike] = []
    @State private var isLoadingBikes = false
    @State private var bikesErrorMessage: String?

    @State private var bikeToConfirm: Bike?
    @State private var isUnlocking = false
    @State private var isBooking = false
    @State private var actionResult: BikeActionSheet.ActionResult?
    @State private var showSignInRequired = false

    /// `station` is a snapshot from the moment the user tapped the marker.
    /// `stationsVM` refreshes on its own about every 10 seconds.
    /// This property re-reads the current bike and dock counts on each refresh.
    /// It does not freeze on the old snapshot while the sheet stays open.
    private var liveStation: MapStation {
        stationsVM.stations.first { $0.id == station.id } ?? station
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statsCard
                directionsButton
                capacitySection
                bikesSection
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: station.id) {
            // This loop keeps the per-bike list current while the sheet stays open.
            // Without it, the list would freeze at the state from when the sheet opened.
            while !Task.isCancelled {
                await loadBikes()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
        .sheet(item: $bikeToConfirm) { bike in
            BikeActionSheet(
                bike: bike,
                isAlreadyBooked: bike.id == bookingVM.activeBooking?.bikeId,
                isUnlocking: isUnlocking,
                isBooking: isBooking,
                result: actionResult,
                onUnlock: { Task { await unlock(bike) } },
                onBook: { Task { await book(bike) } },
                onRetry: { actionResult = nil }
            )
        }
        .alert("Sign In Required", isPresented: $showSignInRequired) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sign in to unlock or book a bike.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(liveStation.name)
                    .font(.title2.bold())

                HStack(spacing: 4) {
                    Circle()
                        .fill(liveStation.isRenting ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(liveStation.isRenting ? "Open" : "Closed")
                        .foregroundStyle(liveStation.isRenting ? .green : .red)
                    if let capacity = liveStation.capacity {
                        Text("· \(capacity) stands")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.medium))
            }

            Spacer()

            if authVM.isAuthenticated, let stationNumber = Int(station.id) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await authVM.toggleFavorite(stationNumber: stationNumber) }
                } label: {
                    Image(systemName: authVM.isFavorite(stationNumber: stationNumber) ? "star.fill" : "star")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(authVM.isFavorite(stationNumber: stationNumber) ? .yellow : .secondary)
                        .padding(8)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .accessibilityLabel(authVM.isFavorite(stationNumber: stationNumber) ? "Remove from favorites" : "Add to favorites")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
        }
    }

    private var directionsButton: some View {
        Button {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: liveStation.coordinate))
            item.name = liveStation.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        } label: {
            Label("Walking Directions", systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            StatTile(systemImage: "bicycle", tint: .red, value: liveStation.mechanicalBikes, label: "Mechanical")
            Divider().frame(height: 36)
            StatTile(systemImage: "bolt.fill", tint: .green, value: liveStation.electricalBikes, label: "Electric")
            Divider().frame(height: 36)
            StatTile(systemImage: "parkingsign", tint: .secondary, value: liveStation.docksAvailable, label: "Free docks")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var capacitySection: some View {
        if let capacity = liveStation.capacity, capacity > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CAPACITY")
                    Spacer()
                    Text("\(capacity) stands")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                CapacityBar(
                    capacity: capacity,
                    mechanical: liveStation.mechanicalBikes,
                    electrical: liveStation.electricalBikes,
                    free: liveStation.docksAvailable
                )

                HStack(spacing: 16) {
                    LegendItem(color: .red, label: "Mechanical \(liveStation.mechanicalBikes)")
                    LegendItem(color: .green, label: "Electric \(liveStation.electricalBikes)")
                    LegendItem(color: Color(.systemGray3), label: "Free \(liveStation.docksAvailable)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var bikesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BIKES AT THIS STATION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if isUnlocking || isBooking {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text(isUnlocking ? "Unlocking…" : "Booking…").font(.caption).foregroundStyle(.secondary)
                }
            }

            if isLoadingBikes {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let bikesErrorMessage {
                Label(bikesErrorMessage, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if bikes.isEmpty {
                Text("No bikes currently docked here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(bikes) { bike in
                        BikeRowView(bike: bike, isBooked: bike.id == bookingVM.activeBooking?.bikeId)
                            .contentShape(Rectangle())
                            .onTapGesture { handleTap(on: bike) }
                        if bike.id != bikes.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .disabled(isUnlocking || isBooking)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Actions

    private func loadBikes() async {
        guard let stationNumber = Int(station.id) else {
            bikesErrorMessage = "Unrecognized station id"
            return
        }
        // Show the full-screen spinner only for the first load.
        // Background refreshes update the list silently. They do not flash the spinner.
        let isInitialLoad = bikes.isEmpty
        if isInitialLoad { isLoadingBikes = true }
        bikesErrorMessage = nil
        defer { if isInitialLoad { isLoadingBikes = false } }
        do {
            let fetched = try await bikeDetailClient.bikes(atStationNumber: stationNumber)
            let bookedId = bookingVM.activeBooking?.bikeId
            bikes = fetched.sorted { lhs, rhs in
                if let bookedId {
                    if lhs.id == bookedId && rhs.id != bookedId { return true }
                    if rhs.id == bookedId && lhs.id != bookedId { return false }
                }
                return (lhs.standNumber ?? .max) < (rhs.standNumber ?? .max)
            }
        } catch {
            bikesErrorMessage = error.localizedDescription
        }
    }

    private func handleTap(on bike: Bike) {
        // A bike that the user has booked shows status `.reserved`, not `.available`.
        // The row stays tappable so the user can unlock the booked bike.
        let isMyBooking = bike.id == bookingVM.activeBooking?.bikeId
        guard bike.status == .available || isMyBooking else { return }
        guard authVM.isAuthenticated else {
            showSignInRequired = true
            return
        }
        actionResult = nil
        bikeToConfirm = bike
    }

    private func unlock(_ bike: Bike) async {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            guard let accountId = authVM.accountId else { throw UnlockError.notAuthenticated }
            let subscriptionId = try await authVM.resolveActiveSubscriptionId()
            let request = ReleaseBikeRequest(
                stationNumber: bike.stationNumber,
                standNumber: bike.standNumber,
                bikeNumber: bike.number
            )
            let response = try await authVM.client.trips.releaseBike(accountId: accountId, subscriptionId: subscriptionId, request: request)
            if response.transactionState == .ok {
                // Unlocking only opens a physical window of about 60 seconds to take the bike out.
                // This is not the same event as the ride start.
                // The message below describes the unlock, not a ride start.
                actionResult = BikeActionSheet.ActionResult(
                    succeeded: true,
                    title: "Bike Unlocked",
                    message: "You have 60 seconds to take bike #\(bike.number) out of the stand."
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await loadBikes()
                tripVM.watchForRideStart()
            } else {
                actionResult = BikeActionSheet.ActionResult(succeeded: false, title: "Unlock Failed", message: "Status: \(response.transactionState.rawValue)")
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        } catch {
            actionResult = BikeActionSheet.ActionResult(succeeded: false, title: "Unlock Failed", message: error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func book(_ bike: Bike) async {
        isBooking = true
        defer { isBooking = false }
        do {
            guard let accountId = authVM.accountId else { throw UnlockError.notAuthenticated }
            guard let stationNumber = bike.stationNumber, let standNumber = bike.standNumber else {
                throw UnlockError.noActiveSubscription(debugInfo: "Bike is missing station/stand number")
            }
            let subscriptionId = try await authVM.resolveActiveSubscriptionId()
            let station = try await authVM.client.stations.station(number: stationNumber)
            let request = CreateBooking(
                stationId: station.id,
                stationNumber: stationNumber,
                standNumber: Int16(clamping: standNumber),
                subscriptionId: subscriptionId,
                bikeId: bike.id
            )
            _ = try await authVM.client.bookings.createBooking(accountId: accountId, booking: request)
            actionResult = BikeActionSheet.ActionResult(succeeded: true, title: "Bike Booked", message: "Bike #\(bike.number) is held for you — walk over and unlock it before the booking expires.")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await bookingVM.refreshActiveBooking()
        } catch {
            actionResult = BikeActionSheet.ActionResult(succeeded: false, title: "Booking Failed", message: error.localizedDescription)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Supporting views

private struct StatTile: View {
    let systemImage: String
    let tint: Color
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

/// A horizontal bar with segments for a station's stands.
/// The segments show mechanical bikes, electric bikes, and free docks.
/// If the counts do not add up to capacity, an extra segment shows the remainder.
private struct CapacityBar: View {
    let capacity: Int
    let mechanical: Int
    let electrical: Int
    let free: Int

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                segment(.red, count: mechanical, totalWidth: geometry.size.width)
                segment(.green, count: electrical, totalWidth: geometry.size.width)
                segment(Color(.systemGray3), count: free, totalWidth: geometry.size.width)
                let accounted = mechanical + electrical + free
                if capacity > accounted {
                    segment(Color(.systemGray5), count: capacity - accounted, totalWidth: geometry.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
    }

    private func segment(_ color: Color, count: Int, totalWidth: CGFloat) -> some View {
        let fraction = capacity > 0 ? CGFloat(count) / CGFloat(capacity) : 0
        return color.frame(width: totalWidth * fraction)
    }
}
