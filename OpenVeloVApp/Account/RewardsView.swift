import SwiftUI
import VLSKit

struct RewardsView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var configurations: [RewardConfiguration] = []
    @State private var isLoading = false
    @State private var isRedeeming = false
    @State private var promoCode: RewardPromoCode?
    @State private var errorMessage: String?
    @State private var showRedeemConfirmation = false

    private var earnableActions: [RewardConfiguration] {
        configurations
            .filter { $0.enable && $0.reward > 0 }
            .sorted { $0.reward > $1.reward }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 6) {
                        Text("\(authVM.rewardBalance ?? 0)")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                        Text("reward points")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                }

                Section {
                    Toggle("Spend points automatically", isOn: Binding(
                        get: { authVM.rewardAutoSpend },
                        set: { newValue in Task { await authVM.setRewardAutoSpend(newValue) } }
                    ))
                } footer: {
                    Text("When this is on, Vélo'v applies your points to charges as they come up, instead of letting them build up.")
                }

                if let promoCode {
                    Section("Your promo code") {
                        LabeledContent("Code", value: promoCode.promoCode)
                            .textSelection(.enabled)
                        LabeledContent("Points spent", value: "\(promoCode.rewardsSpent)")
                    }
                }

                Section {
                    Button {
                        showRedeemConfirmation = true
                    } label: {
                        HStack {
                            Label("Turn points into a promo code", systemImage: "ticket")
                            Spacer()
                            if isRedeeming { ProgressView() }
                        }
                    }
                    .disabled(isRedeeming || (authVM.rewardBalance ?? 0) <= 0)
                } footer: {
                    Text("Converts your balance into a promotional code you can use against a Vélo'v purchase. Vélo'v decides how many points it takes.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if isLoading && earnableActions.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Loading…").foregroundStyle(.secondary)
                        }
                    } else if earnableActions.isEmpty {
                        Text("Vélo'v didn't return the list of rewarded actions for this contract.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(earnableActions, id: \.i18nKey) { configuration in
                            HStack {
                                Text(label(for: configuration))
                                Spacer()
                                Text("+\(configuration.reward)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .monospacedDigit()
                            }
                        }
                    }
                } header: {
                    Text("How to earn")
                }
            }
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                "Convert your points?",
                isPresented: $showRedeemConfirmation,
                titleVisibility: .visible
            ) {
                Button("Create Promo Code") { Task { await redeem() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This spends reward points from your account and cannot be undone from here.")
            }
        }
        .task { await load() }
    }

    /// The API sends a localization key, not display text; unknown keys fall back to the key.
    private func label(for configuration: RewardConfiguration) -> String {
        switch configuration.name {
        case .startStationFull: return String(localized: "Take a bike from a full station")
        case .endStationEmpty: return String(localized: "Return a bike to an empty station")
        case .rateBike: return String(localized: "Rate a bike after a ride")
        case .startTripOverflow: return String(localized: "Start a ride from overflow parking")
        case .tripBonus: return String(localized: "Ride bonus")
        case .migrateBonus: return String(localized: "Switch to a new subscription")
        case .currency: return String(localized: "Cash-equivalent reward")
        case .promocode: return String(localized: "Use a promo code")
        case .bikeBooking: return String(localized: "Book a bike in advance")
        case .unknown, .none:
            return configuration.i18nKey
                .split(whereSeparator: { $0 == "." || $0 == "_" })
                .last
                .map { $0.replacingOccurrences(of: "-", with: " ").capitalized }
                ?? configuration.i18nKey
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await authVM.refreshReward()
        configurations = (try? await authVM.client.rewards.configurations()) ?? []
    }

    private func redeem() async {
        guard let accountId = authVM.accountId else { return }
        isRedeeming = true
        defer { isRedeeming = false }
        do {
            promoCode = try await authVM.client.rewards.consumePromoCode(accountId: accountId)
            errorMessage = nil
            await authVM.refreshReward()
        } catch {
            errorMessage = UserFacingError.message(for: error, context: .account)
        }
    }
}
