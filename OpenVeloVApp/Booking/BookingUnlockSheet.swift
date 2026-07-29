import SwiftUI

struct BookingUnlockSheet: View {
    let isUnlocking: Bool
    let result: BikeActionSheet.ActionResult?
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let result {
                resultView(result)
            } else {
                progressView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isUnlocking)
        .onChange(of: result?.id) { _, _ in
            guard let result, result.succeeded else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                dismiss()
            }
        }
    }

    private var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Unlocking your bike…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func resultView(_ result: BikeActionSheet.ActionResult) -> some View {
        VStack(spacing: 12) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(result.succeeded ? .green : .red)
            Text(result.title)
                .font(.headline)
            Text(result.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !result.succeeded {
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("Try Again") { onRetry() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
