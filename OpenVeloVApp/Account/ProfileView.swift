import SwiftUI
import VLSKit
import VLSKitUI

/// This sheet opens from the profile button on the map. It shows a sign-in prompt when
/// the rider is signed out, and the account summary with a sign-out button when signed in.
struct ProfileView: View {
    @ObservedObject var authVM: AuthViewModel
    /// Called after `authVM.logout()`, so the caller can reset trip/booking tracking —
    var onSignOut: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

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
    }

    private var signInSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Sign in with your Vélo'v account to manage bookings and subscriptions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var accountSection: some View {
        List {
            Section {
                if authVM.isLoadingAccount && authVM.account == nil {
                    HStack {
                        ProgressView()
                        Text("Loading account…").foregroundStyle(.secondary)
                    }
                } else if let account = authVM.account {
                    LabeledContent("Email", value: account.email)
                    let fullName = [account.firstName, account.lastName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !fullName.isEmpty {
                        LabeledContent("Name", value: fullName)
                    }
                    if let rewardBalance = authVM.rewardBalance {
                        LabeledContent("Reward Points", value: "\(rewardBalance)")
                    }
                }
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
                    Task {
                        await authVM.logout()
                        onSignOut()
                    }
                }
            }
        }
    }
}
