import CoreLocation
import SwiftUI
import WatchKit

struct WatchContentView: View {
    @StateObject private var store = WatchStationStore()
    @StateObject private var locationManager = WatchLocationManager()
    @StateObject private var link = WatchConnectivityClient()

    @State private var isUnlockingBooking = false
    @State private var bookingResult: (success: Bool, message: String)?

    var body: some View {
        NavigationStack {
            List {
                if link.hasBooking {
                    Section("Booked bike") {
                        bookingUnlock
                    }
                }

                if let message = store.errorMessage, store.nearby.isEmpty {
                    Section {
                        Label(message, systemImage: "wifi.exclamationmark").font(.footnote)
                    }
                } else if store.nearby.isEmpty && store.isLoading {
                    Section {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                }

                Section("Nearest") {
                    HighlightRow(title: "Bike", systemImage: "bicycle", tint: .green,
                                 pair: store.nearestBike, count: { $0.totalBikes })
                    HighlightRow(title: "Dock", systemImage: "parkingsign", tint: .blue,
                                 pair: store.nearestDock, count: { $0.docks })
                }

                if !store.nearby.isEmpty {
                    Section("Nearby") {
                        ForEach(store.nearby) { station in
                            NavigationLink {
                                WatchStationDetailView(station: station, link: link)
                            } label: {
                                WatchStationRow(station: station, distance: store.distance(to: station))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vélo'v")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
            }
        }
        .task {
            locationManager.requestAuthorization()
            await reload()
        }
        .onChange(of: locationManager.location) { _, _ in
            Task { await reload() }
        }
    }

    @ViewBuilder
    private var bookingUnlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let station = link.bookingStationName {
                Text(station).font(.footnote.weight(.semibold)).lineLimit(1)
            }
            if let bike = link.bookingBikeNumber, bike > 0 {
                Text("Bike #\(String(bike))").font(.caption2).foregroundStyle(.secondary)
            }
            if let end = link.bookingEnd {
                Text("Held until \(end, style: .time)").font(.caption2).foregroundStyle(.secondary)
            }

            Button {
                unlockBooking()
            } label: {
                if isUnlockingBooking {
                    ProgressView()
                } else {
                    Label("Unlock", systemImage: "lock.open.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(isUnlockingBooking || !link.isReachable)

            if let bookingResult {
                Text(bookingResult.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(bookingResult.success ? .green : .red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !link.isReachable {
                Text("Open OpenVeloV on your iPhone to unlock.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func unlockBooking() {
        isUnlockingBooking = true
        bookingResult = nil
        Task {
            let outcome = await link.unlockBooking()
            isUnlockingBooking = false
            bookingResult = outcome
            WKInterfaceDevice.current().play(outcome.success ? .success : .failure)
        }
    }

    private func reload() async {
        locationManager.requestLocation()
        await store.load(near: locationManager.location?.coordinate)
    }
}

/// The "nearest bike / nearest dock" hero rows.
private struct HighlightRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let pair: (station: WatchStation, distance: CLLocationDistance)?
    let count: (WatchStation) -> Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                if let pair {
                    Text(pair.station.name).font(.footnote.weight(.semibold)).lineLimit(1)
                    Text("\(watchDistanceText(pair.distance)) away").font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("None nearby").font(.footnote).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let pair {
                Text("\(count(pair.station))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(tint)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
