import SwiftUI
import VLSKit
import VLSKitUI

struct ProfileView: View {
    @ObservedObject var authVM: AuthViewModel
    /// Called after `authVM.logout()`, so the caller can reset trip/booking tracking.
    var onSignOut: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    @State private var showRewards = false
    @State private var showBilling = false
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if authVM.isAuthenticated {
                    accountSection
                } else {
                    signInSection
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $authVM.isPresentingLogin) {
            if let pending = authVM.pendingAuthorization {
                LoginView(pending: pending, redirectURI: authVM.redirectURI, onRedirect: authVM.handleLoginRedirect)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showRewards) {
            RewardsView(authVM: authVM)
        }
        .sheet(isPresented: $showBilling) {
            BillingView(authVM: authVM)
        }
    }

    private var signInSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(.largeTitle))
                .imageScale(.large)
                .foregroundStyle(.secondary)
            Text("Sign in with your Vélo'v account to manage bookings and subscriptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if !AppSecrets.isConfigured {
                // Without the credential the anonymous device token can't be minted, so the server
                // rejects every signed-in call; warn here rather than let sign-in fail obscurely.
                Label(
                    "This build has no Vélo'v web-client credential, so signing in won't work. See Config/Secrets.example.xcconfig.",
                    systemImage: "key.slash"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }

            if let errorMessage = authVM.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await authVM.startLogin() }
            } label: {
                Text("Sign In").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!AppSecrets.isConfigured)
            .padding(.horizontal, 40)

            Text("The map, search, and favorites all work without an account.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var accountSection: some View {
        List {
            if let blockingAlertMessage = authVM.blockingAlertMessage {
                Section {
                    Label(blockingAlertMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                if authVM.isLoadingAccount && authVM.account == nil {
                    HStack {
                        ProgressView()
                        Text("Loading account…").foregroundStyle(.secondary)
                    }
                } else if let account = authVM.account {
                    LabeledContent("Email", value: account.email)
                    if let displayName = authVM.displayName {
                        LabeledContent("Name", value: displayName)
                    }
                }
            }

            Section {
                Button {
                    showRewards = true
                } label: {
                    HStack {
                        Label("Rewards", systemImage: "star.circle")
                        Spacer()
                        if let rewardBalance = authVM.rewardBalance {
                            Text("\(rewardBalance) pts")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showBilling = true
                } label: {
                    HStack {
                        Label("Billing", systemImage: "creditcard")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }

            if let errorMessage = authVM.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    showSignOutConfirmation = true
                }
            } footer: {
                Text("Your starred stations stay on this device after you sign out.")
            }
        }
        .confirmationDialog("Sign out of your Vélo'v account?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await authVM.logout()
                    onSignOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
