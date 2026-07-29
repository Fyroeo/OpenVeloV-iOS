import SwiftUI
import VLSKit

struct SubscriptionDetailView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var subscriptions: [Subscription] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && subscriptions.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Load Subscriptions", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    }
                } else if subscriptions.isEmpty {
                    ContentUnavailableView("No Subscriptions", systemImage: "creditcard", description: Text("You don't have any Vélo'v subscriptions on this account."))
                } else {
                    List {
                        ForEach(subscriptions) { subscription in
                            Section {
                                subscriptionSection(subscription)
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func subscriptionSection(_ subscription: Subscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel(subscription.type))
                    .font(.headline)
                if let displayRef = subscription.displayRef {
                    Text(displayRef)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            statusBadge(for: subscription)
        }

        // An expired or not-yet-started subscription has no period covering today, so fall back to
        // the one that ends latest.
        if let current = currentPeriod(subscription) ?? subscription.periods.sorted(by: { $0.validityEnd > $1.validityEnd }).first {
            LabeledContent("Valid from", value: current.validityStart.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Valid until", value: current.validityEnd.formatted(date: .abbreviated, time: .omitted))
            if let renewal = current.renewalDetails {
                LabeledContent("Auto-renewal", value: renewal.isAutoRenewal ? "On" : "Off")
            }
        }

        if subscription.isLocked {
            Label("This subscription is locked", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func statusBadge(for subscription: Subscription) -> some View {
        let isActive = currentPeriod(subscription) != nil && !subscription.isLocked
        (isActive ? Text("Active") : Text("Inactive"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .green : .secondary)
    }

    private func currentPeriod(_ subscription: Subscription) -> SubscriptionPeriod? {
        let now = Date()
        return subscription.periods.first { $0.validityStart <= now && now <= $0.validityEnd }
    }

    private func typeLabel(_ type: SubscriptionType?) -> String {
        switch type {
        case .longTerm: return String(localized: "Long-term subscription")
        case .shortTerm: return String(localized: "Short-term subscription")
        case .ub: return String(localized: "Pay-as-you-go")
        case .parking: return String(localized: "Parking subscription")
        case .battery: return String(localized: "Battery subscription")
        case nil: return String(localized: "Subscription")
        }
    }

    private func load() async {
        guard let accountId = authVM.accountId else {
            errorMessage = String(localized: "Sign in to see your subscription.")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            subscriptions = try await authVM.client.subscriptions.subscriptions(accountId: accountId)
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .subscription)
        }
    }
}
