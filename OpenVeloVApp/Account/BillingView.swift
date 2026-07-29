import QuickLook
import SwiftUI
import VLSKit

struct BillingView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var balance: Balance?
    @State private var transactions: [VLSKit.Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var billURL: URL?
    @State private var downloadingTransactionID: UUID?
    @State private var billError: String?

    private var sortedTransactions: [VLSKit.Transaction] {
        transactions.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && transactions.isEmpty && balance == nil {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, transactions.isEmpty, balance == nil {
                    ContentUnavailableView {
                        Label("Couldn't Load Billing", systemImage: "creditcard")
                    } description: {
                        Text(errorMessage)
                    }
                } else {
                    List {
                        if let balance {
                            Section("Balance") {
                                LabeledContent("Due now", value: currencyText(Int64(balance.due)))
                                if balance.dueToControl != 0 {
                                    LabeledContent("Pending", value: currencyText(Int64(balance.dueToControl)))
                                }
                                LabeledContent("Credit", value: currencyText(Int64(balance.credit)))
                            }
                        }

                        if let billError {
                            Section {
                                Label(billError, systemImage: "exclamationmark.triangle")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Section("Transactions") {
                            if sortedTransactions.isEmpty {
                                Text("No transactions on this account.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(sortedTransactions) { transaction in
                                    TransactionRow(
                                        transaction: transaction,
                                        isDownloading: downloadingTransactionID == transaction.id,
                                        onDownloadBill: { Task { await downloadBill(for: transaction) } }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Billing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await load() }
        .quickLookPreview($billURL)
    }

    private func load() async {
        guard let accountId = authVM.accountId else {
            errorMessage = String(localized: "Sign in to see your billing.")
            return
        }
        isLoading = true
        defer { isLoading = false }
        async let balanceTask = try? await authVM.client.invoices.balance(accountId: accountId)
        async let transactionsTask = try? await authVM.client.invoices.transactions(accountId: accountId)
        let (loadedBalance, loadedTransactions) = await (balanceTask, transactionsTask)
        balance = loadedBalance
        transactions = loadedTransactions ?? []
        errorMessage = (loadedBalance == nil && loadedTransactions == nil)
            ? String(localized: "Couldn't load your billing details.")
            : nil
    }

    /// Bills come back as raw PDF bytes, so they land in a temporary file and open in Quick Look.
    private func downloadBill(for transaction: VLSKit.Transaction) async {
        guard let accountId = authVM.accountId else { return }
        downloadingTransactionID = transaction.id
        defer { downloadingTransactionID = nil }
        do {
            let data = try await authVM.client.invoices.bill(accountId: accountId, transactionId: transaction.id)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("velov-bill-\(transaction.id.uuidString).pdf")
            try data.write(to: url, options: .atomic)
            billError = nil
            billURL = url
        } catch {
            billError = UserFacingError.message(for: error, context: .generic)
        }
    }
}

private struct TransactionRow: View {
    let transaction: VLSKit.Transaction
    let isDownloading: Bool
    let onDownloadBill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(natureLabel)
                        .font(.subheadline.weight(.semibold))
                    if let createdAt = transaction.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(currencyText(Int64(transaction.amount)))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            HStack {
                if let statusLabel {
                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDownloadBill) {
                    if isDownloading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("Bill", systemImage: "doc.text")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isDownloading)
            }
        }
        .padding(.vertical, 2)
    }

    /// `InvoiceStatus` is a raw server enum; its case name is not display text.
    private var statusLabel: String? {
        switch transaction.status {
        case .toControl: return String(localized: "Awaiting check")
        case .toInvoice: return String(localized: "To be invoiced")
        case .toDo, .doing: return String(localized: "Processing")
        case .cancelled: return String(localized: "Cancelled")
        case .rejected: return String(localized: "Rejected")
        case .paid: return String(localized: "Paid")
        case .paybacked: return String(localized: "Refunded")
        case .partiallyPaybacked: return String(localized: "Partially refunded")
        case .unknown, .none: return nil
        }
    }

    private var natureLabel: String {
        switch transaction.nature {
        case .caution: return String(localized: "Deposit")
        case .refund: return String(localized: "Refund")
        case .subscription: return String(localized: "Subscription")
        case .renewal: return String(localized: "Renewal")
        case .consumption: return String(localized: "Ride charges")
        case .regularization: return String(localized: "Adjustment")
        case .mixed: return String(localized: "Mixed charges")
        case .none: return String(localized: "Transaction")
        }
    }
}
