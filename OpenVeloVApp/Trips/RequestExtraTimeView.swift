import CoreLocation
import SwiftUI
import VLSKit

/// This view shows the "ask for 15 more minutes" screen. This is JCDecaux's "via" feature.
/// The feature is valid only when the destination station has no free docks. For this
/// reason, this view lists only stations with 0 free docks, nearest first.
struct RequestExtraTimeView: View {
    @ObservedObject var authVM: AuthViewModel
    let stations: [MapStation]
    let userLocation: CLLocationCoordinate2D?

    @Environment(\.dismiss) private var dismiss
    @State private var submittingStationID: String?
    @State private var resultTitle: String?
    @State private var resultMessage: String?
    @State private var resultWasError = false

    private var fullStations: [MapStation] {
        let full = stations.filter { $0.isReturning && $0.docksAvailable == 0 }
        guard let userLocation else { return full }
        let here = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        return full.sorted {
            CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude).distance(from: here)
                < CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude).distance(from: here)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if fullStations.isEmpty {
                    ContentUnavailableView(
                        "No Full Stations Right Now",
                        systemImage: "checkmark.circle",
                        description: Text("The 15-minute extension only applies when your destination station has no free docks.")
                    )
                } else {
                    List(fullStations) { station in
                        Button {
                            Task { await requestExtraTime(at: station) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Full · 0 docks free")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if submittingStationID == station.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "clock.badge.plus")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .disabled(submittingStationID != nil)
                    }
                }
            }
            .navigationTitle("Ask for 15 More Minutes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert(
                resultTitle ?? "",
                isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } }),
                presenting: resultMessage
            ) { _ in
                Button("OK") {
                    if !resultWasError { dismiss() }
                }
            } message: { message in
                Text(message)
            }
        }
    }

    private func requestExtraTime(at station: MapStation) async {
        guard let stationId = Int64(station.id) else {
            resultTitle = "Couldn't Request Extra Time"
            resultMessage = "This station's number couldn't be resolved."
            resultWasError = true
            return
        }
        guard let accountId = authVM.accountId else {
            resultTitle = "Couldn't Request Extra Time"
            resultMessage = "Not signed in."
            resultWasError = true
            return
        }
        submittingStationID = station.id
        defer { submittingStationID = nil }
        do {
            let subscriptionId = try await authVM.resolveActiveSubscriptionId()
            let state = try await authVM.client.subscriptions.requestExtraTime(
                accountId: accountId,
                subscriptionId: subscriptionId,
                stationId: stationId
            )
            if state == .ok {
                resultTitle = "You've Got 15 More Minutes"
                resultMessage = "Find another station to dock your bike."
                resultWasError = false
            } else {
                resultTitle = "Request Didn't Go Through"
                resultMessage = "Status: \(state.rawValue)"
                resultWasError = true
            }
        } catch {
            resultTitle = "Couldn't Request Extra Time"
            resultMessage = error.localizedDescription
            resultWasError = true
        }
    }
}
