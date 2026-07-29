import SwiftUI
import VLSKit

struct RateBikeView: View {
    let trip: Trip
    @ObservedObject var authVM: AuthViewModel
    var didUploadRoute: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)

                Image(systemName: trip.bikeType == .electrical ? "bolt.fill" : "bicycle")
                    .font(.system(.largeTitle))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(trip.bikeType == .electrical ? Color.green : Color.red, in: Circle())

                VStack(spacing: 4) {
                    Text(bikeLabel)
                        .font(.title3.bold())
                    Text("Would you recommend this bike to other riders?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if didUploadRoute {
                    Label("Route saved to this ride", systemImage: "map.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 28) {
                    ratingButton(recommended: false, systemImage: "hand.thumbsdown.fill", tint: .red)
                    ratingButton(recommended: true, systemImage: "hand.thumbsup.fill", tint: .green)
                }
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.5 : 1)
                .overlay {
                    if isSubmitting {
                        ProgressView()
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Rate Your Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private var bikeLabel: String {
        if let number = trip.bikeNumber {
            return String(localized: "How was bike #\(number.identifierText)?")
        }
        return String(localized: "How was your ride?")
    }

    private func ratingButton(recommended: Bool, systemImage: String, tint: Color) -> some View {
        Button {
            Task { await submit(recommended: recommended) }
        } label: {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(tint, in: Circle())
        }
    }

    private func submit(recommended: Bool) async {
        guard let accountId = authVM.accountId, let tripId = trip.id, let bikeNumber = trip.bikeNumber else {
            errorMessage = String(localized: "This ride is missing details needed to rate it.")
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let rate = Rate(bikeId: bikeNumber, recommended: recommended, contract: authVM.client.environment.contract)
            _ = try await authVM.client.bikes.rate(accountId: accountId, tripId: tripId, rate: rate)
            dismiss()
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .trips)
        }
    }
}
