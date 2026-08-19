import SwiftUI
import WatchKit

struct WatchStationDetailView: View {
    let station: WatchStation
    @ObservedObject var link: WatchConnectivityClient

    @State private var bikes: [WatchBike]?          // nil until first load / when unreachable
    @State private var isLoading = false
    @State private var pendingBike: WatchBike?      // awaiting confirmation
    @State private var unlockingNumber: Int?
    @State private var result: (success: Bool, message: String)?

    private var stationNumber: Int? { Int(station.number) }

    var body: some View {
        List {
            Section {
                counts
            }

            if let result {
                Section {
                    resultBox(result)
                }
            }

            Section("Pick a bike") {
                bikeListContent
            }
        }
        .navigationTitle(station.name)
        .task { await load() }
        .confirmationDialog(confirmTitle, isPresented: confirmBinding, titleVisibility: .visible) {
            Button("Unlock") {
                if let bike = pendingBike { unlock(bike) }
                pendingBike = nil
            }
            Button("Cancel", role: .cancel) { pendingBike = nil }
        }
    }

    // MARK: - Bike list

    @ViewBuilder
    private var bikeListContent: some View {
        if !link.isAuthenticated {
            hint("Sign in on your iPhone to unlock.")
        } else if isLoading {
            HStack { Spacer(); ProgressView(); Spacer() }
        } else if bikes == nil {
            VStack(alignment: .leading, spacing: 8) {
                hint("Open OpenVeloV on your iPhone to pick a bike.")
                Button("Retry") { Task { await load() } }
            }
        } else if let bikes, bikes.isEmpty {
            hint("No bikes available here.")
        } else if let bikes {
            ForEach(bikes) { bike in
                Button {
                    pendingBike = bike
                } label: {
                    bikeRow(bike)
                }
                .disabled(unlockingNumber != nil)
            }
        }
    }

    private func bikeRow(_ bike: WatchBike) -> some View {
        HStack(spacing: 10) {
            Image(systemName: bike.isElectric ? "bolt.fill" : "bicycle")
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(bike.isElectric ? Color.green : Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Bike #\(String(bike.number))").font(.footnote.weight(.semibold))
                HStack(spacing: 6) {
                    if let stand = bike.stand {
                        Text("Stand \(String(stand))")
                    }
                    if bike.isElectric, let battery = bike.battery {
                        Text(verbatim: "· \(battery)%")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if unlockingNumber == bike.number {
                ProgressView()
            } else {
                Image(systemName: "lock.open").font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var counts: some View {
        HStack(spacing: 12) {
            countTile(icon: "bicycle", value: station.mechanical, tint: .red)
            countTile(icon: "bolt.fill", value: station.electric, tint: .green)
            countTile(icon: "parkingsign", value: station.docks, tint: .blue)
        }
    }

    private func countTile(icon: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.footnote).foregroundStyle(tint)
            Text("\(value)").font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private func resultBox(_ result: (success: Bool, message: String)) -> some View {
        VStack(spacing: 6) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.octagon.fill").font(.title3)
            Text(result.message).font(.footnote.weight(.semibold)).multilineTextAlignment(.center)
        }
        .foregroundStyle(result.success ? .green : .red)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption2).foregroundStyle(.secondary)
    }

    // MARK: - Logic

    private var confirmTitle: LocalizedStringKey {
        if let bike = pendingBike { return "Unlock bike #\(String(bike.number))?" }
        return "Unlock this bike?"
    }

    private var confirmBinding: Binding<Bool> {
        Binding(get: { pendingBike != nil }, set: { if !$0 { pendingBike = nil } })
    }

    private func load() async {
        guard link.isAuthenticated, let stationNumber else { return }
        isLoading = true
        defer { isLoading = false }
        bikes = await link.bikes(atStation: stationNumber)
    }

    private func unlock(_ bike: WatchBike) {
        guard let stationNumber else {
            result = (false, String(localized: "This station's number couldn't be read."))
            return
        }
        unlockingNumber = bike.number
        result = nil
        Task {
            let outcome = await link.unlock(bike, atStation: stationNumber)
            unlockingNumber = nil
            result = outcome
            WKInterfaceDevice.current().play(outcome.success ? .success : .failure)
            if outcome.success { await load() }
        }
    }
}
