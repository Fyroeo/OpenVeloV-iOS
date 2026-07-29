import SwiftUI
import VLSKit

struct BikeLookupView: View {
    let bikeDetailClient: BikeDetailClient
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var stationsVM: StationsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    @State private var query = ""
    @State private var results: [Bike] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var canSearch: Bool {
        !trimmedQuery.isEmpty && Int(trimmedQuery) != nil && !isSearching
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                content
            }
            .navigationTitle("Find a Bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { isFieldFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                TextField("Bike number, e.g. 25391", text: $query)
                    .keyboardType(.numberPad)
                    .focused($isFieldFocused)
                    .onChange(of: query) { _, _ in
                        results = []
                        errorMessage = nil
                        hasSearched = false
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))

            Button {
                isFieldFocused = false
                Task { await search() }
            } label: {
                if isSearching {
                    ProgressView().controlSize(.small)
                        .frame(width: 60)
                } else {
                    Text("Search").frame(minWidth: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSearch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            ProgressView("Looking up…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Find That Bike", systemImage: "bicycle")
            } description: {
                Text(errorMessage)
            }
        } else if results.isEmpty {
            ContentUnavailableView {
                Label(hasSearched ? LocalizedStringKey("No Bike With That Number") : LocalizedStringKey("Look Up a Bike"), systemImage: "number")
            } description: {
                hasSearched
                ? Text("Vélo'v has no record of a bike with that number, or it isn't currently docked.")
                : Text("Type the number printed on a Vélo'v frame to see its rating, battery, and where it is.")
            }
        } else {
            List {
                ForEach(results) { bike in
                    Section {
                        BikeRowView(bike: bike)
                        if let stationNumber = bike.stationNumber {
                            LabeledContent("Station", value: stationsVM.name(forNumber: stationNumber) ?? "Station \(stationNumber)")
                        }
                        if let standNumber = bike.standNumber {
                            LabeledContent("Stand", value: "\(standNumber)")
                        }
                        if let lastRating = bike.rating.lastRatingDateTime {
                            LabeledContent("Last rated", value: lastRating.formatted(.relative(presentation: .named)))
                        }
                    }
                }
            }
        }
    }

    private func search() async {
        guard let number = Int(trimmedQuery) else {
            errorMessage = String(localized: "Bike numbers are digits only.")
            results = []
            hasSearched = true
            return
        }
        isSearching = true
        hasSearched = true
        defer { isSearching = false }
        do {
            // Same endpoint either way; the anonymous client is only here so signed-out riders can
            // still look a bike up.
            if authVM.isAuthenticated {
                results = try await authVM.client.bikes.bike(number: number)
            } else {
                results = try await bikeDetailClient.bike(number: number)
            }
            errorMessage = nil
        } catch {
            results = []
            errorMessage = UserFacingError.message(for: error, context: .bikes)
        }
    }
}
