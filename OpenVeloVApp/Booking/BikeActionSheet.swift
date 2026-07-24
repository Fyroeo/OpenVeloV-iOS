import SwiftUI
import VLSKit

/// This sheet confirms an unlock or a booking action for a bike.
/// It shows one continuous surface: choice, then progress, then result.
struct BikeActionSheet: View {
    let bike: Bike
    let isAlreadyBooked: Bool
    let isUnlocking: Bool
    let isBooking: Bool
    let result: ActionResult?
    let onUnlock: () -> Void
    let onBook: () -> Void
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss

    struct ActionResult: Identifiable {
        let id = UUID()
        let succeeded: Bool
        let title: String
        let message: String
    }

    private var typeColor: Color { bike.type == .electrical ? .green : .red }

    var body: some View {
        VStack(spacing: 24) {
            bikeHeader

            if let result {
                resultView(result)
            } else if isUnlocking || isBooking {
                progressView
            } else {
                actionButtons
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isUnlocking || isBooking)
        .onChange(of: result?.id) { _, _ in
            guard let result, result.succeeded else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                dismiss()
            }
        }
    }

    private var bikeHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: bike.type == .electrical ? "bolt.fill" : "bicycle")
                .font(.system(size: 32))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(typeColor, in: Circle())

            Text("Bike #\(bike.number)")
                .font(.title3.bold())

            HStack(spacing: 6) {
                Text(bike.type == .electrical ? "Electric" : "Mechanical")
                if let standNumber = bike.standNumber {
                    Text("· Stand \(standNumber)")
                }
                if let value = bike.rating.value {
                    Text("· \(Int(value))% recommended")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let battery = bike.battery {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                    Text("\(battery.percentage)% battery")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            ActionButton(
                title: "Unlock Now",
                subtitle: "Starts a real, billable ride immediately",
                systemImage: "lock.open.fill",
                tint: .red,
                action: onUnlock
            )
            if !isAlreadyBooked {
                ActionButton(
                    title: "Book for Later",
                    subtitle: "Holds this bike for you, no charge yet",
                    systemImage: "clock.badge.checkmark",
                    tint: .blue,
                    action: onBook
                )
            }
        }
    }

    private var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(isUnlocking ? "Unlocking bike #\(bike.number)…" : "Booking bike #\(bike.number)…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func resultView(_ result: ActionResult) -> some View {
        VStack(spacing: 12) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 40))
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

/// This button shows one row-style choice in `BikeActionSheet`.
/// `BikeActionSheet` uses it for the "Unlock Now" and "Book for Later" choices.
struct ActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tint, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
