import SwiftUI
import VLSKit

/// This view shows a thumbs up or thumbs down prompt. It shows after a ride, or from the
/// ride history. It calls `POST .../trips/{tripId}/rate`.
///
/// History: this view used to show a "what went wrong?" defect-reason picker before a
/// thumbs-down rating, using `Rate.cdrCode` to match `DefectType.code`.
/// `DefectTypeService.defectTypes` returns 403 (`role.not.allowed`) even for a
/// signed-in account, so the picker could never load and was removed. A thumbs-down
/// rating now submits directly, with no `cdrCode`, the same as thumbs-up.
struct RateBikeView: View {
    let trip: Trip
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 0)

                Image(systemName: trip.bikeType == .electrical ? "bolt.fill" : "bicycle")
                    .font(.system(size: 44))
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
            return "How was bike #\(number)?"
        }
        return "How was your ride?"
    }

    private func ratingButton(recommended: Bool, systemImage: String, tint: Color) -> some View {
        Button {
            Task { await submit(recommended: recommended) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(tint, in: Circle())
        }
    }

    private func submit(recommended: Bool) async {
        guard let accountId = authVM.accountId, let tripId = trip.id, let bikeNumber = trip.bikeNumber else {
            errorMessage = "This ride is missing details needed to rate it."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let rate = Rate(bikeId: bikeNumber, recommended: recommended, contract: authVM.client.environment.contract)
            _ = try await authVM.client.bikes.rate(accountId: accountId, tripId: tripId, rate: rate)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
