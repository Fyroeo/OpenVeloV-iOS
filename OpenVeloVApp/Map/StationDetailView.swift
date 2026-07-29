import MapKit
import SwiftUI
import UIKit
import VLSKit

struct StationDetailView: View {
    let station: MapStation
    let bikeDetailClient: BikeDetailClient
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var tripVM: TripViewModel
    @ObservedObject var bookingVM: BookingViewModel
    @ObservedObject var stationsVM: StationsViewModel
    @ObservedObject var favorites: FavoritesStore
    var userLocation: UserLocation?
    /// Dismisses this sheet and starts the sign-in flow.
    var onRequestSignIn: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // Not `private`: the bike list and actions live in StationDetailView+Actions.swift, an
    // extension in another file, which can only reach internal members.
    @State var bikes: [Bike] = []
    @State var isLoadingBikes = false
    @State var bikesErrorMessage: String?

    @State var bikeToConfirm: Bike?
    @State var isUnlocking = false
    @State var isBooking = false
    @State var actionResult: BikeActionSheet.ActionResult?
    @State var showSignInRequired = false
    @State var bikeSort: BikeSort = .stand

    enum BikeSort: String, CaseIterable, Identifiable {
        case stand
        case battery
        case rating

        var id: Self { self }

        var label: String {
            switch self {
            case .stand: return String(localized: "Stand")
            case .battery: return String(localized: "Battery")
            case .rating: return String(localized: "Rating")
            }
        }
    }

    /// `station` is a snapshot from the moment the marker was tapped, so counts are re-read from
    /// `stationsVM` on every refresh rather than freezing while the sheet stays open.
    private var liveStation: MapStation {
        stationsVM.station(forNumber: station.number) ?? station
    }

    private var hasBonus: Bool { stationsVM.hasBonus(stationNumber: station.number) }

    private var distance: Double? { liveStation.distance(from: userLocation) }

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
            Button("Sign In") { onRequestSignIn() }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Sign in with your Vélo'v account to unlock or book a bike.")
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
                    (liveStation.isRenting ? Text("Open") : Text("Closed"))
                        .foregroundStyle(liveStation.isRenting ? .green : .red)
                    if let distance, MapStation.walkingTimeText(for: distance) != nil {
                        Text("· \(MapStation.distanceText(distance)) · ~\(MapStation.walkingMinutes(for: distance)) min walk")
                            .foregroundStyle(.secondary)
                    } else if let distance {
                        Text("· \(MapStation.distanceText(distance))")
                            .foregroundStyle(.secondary)
                    } else if let capacity = liveStation.capacity {
                        Text("· \(capacity) stands")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.medium))

                if hasBonus {
                    Label("Bonus station — earn reward points here", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }

            Spacer()

            if let stationNumber = station.number {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        await favorites.toggle(
                            stationNumber,
                            client: authVM.isAuthenticated ? authVM.client : nil,
                            accountId: authVM.accountId
                        )
                    }
                } label: {
                    Image(systemName: favorites.contains(stationNumber) ? "star.fill" : "star")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(favorites.contains(stationNumber) ? .yellow : .secondary)
                        .padding(8)
                        .background(Color(.tertiarySystemFill), in: Circle())
                }
                .accessibilityLabel(favorites.contains(stationNumber) ? "Remove from favorites" : "Add to favorites")
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
            .accessibilityLabel("Close")
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
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var bikesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BIKES AT THIS STATION")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if isUnlocking || isBooking {
                    ProgressView().controlSize(.small)
                    (isUnlocking ? Text("Unlocking…") : Text("Booking…")).font(.caption).foregroundStyle(.secondary)
                } else if bikes.count > 1 {
                    sortMenu
                }
            }

            if isLoadingBikes {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if !ContentView.isBikeDetailConfigured {
                Label(
                    "Per-bike detail isn't available in this build — it needs the public site's anonymous web-client credential, which this open-source repository doesn't ship.",
                    systemImage: "key.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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
                    ForEach(sortedBikes) { bike in
                        UnlockableBikeRow(
                            bike: bike,
                            isBooked: bike.id == bookingVM.activeBooking?.bikeId,
                            isRecommended: bike.id == recommendedBikeID,
                            isUnlockable: canUnlock(bike),
                            onTap: { handleTap(on: bike) },
                            onUnlock: { directUnlock(bike) }
                        )
                        if bike.id != sortedBikes.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .disabled(isUnlocking || isBooking)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $bikeSort) {
                ForEach(BikeSort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Label(bikeSort.label, systemImage: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
        }
        .accessibilityLabel("Sort bikes by \(bikeSort.label)")
    }
}
