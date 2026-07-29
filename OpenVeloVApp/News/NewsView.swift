import SwiftUI
import VLSKit

struct NewsView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var feed: RSSFeed?
    @State private var events: [DisplayableEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && feed == nil && events.isEmpty {
                    ProgressView("Loading news…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if feed?.items.isEmpty != false && events.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to Report", systemImage: "newspaper")
                    } description: {
                        Text(errorMessage ?? String(localized: "Vélo'v isn't publishing any news or service alerts right now."))
                    }
                } else {
                    List {
                        if !events.isEmpty {
                            Section {
                                ForEach(events) { event in
                                    EventRow(event: event)
                                }
                            } header: {
                                Label("Service alerts", systemImage: "exclamationmark.triangle.fill")
                            }
                        }

                        if let feed, !feed.items.isEmpty {
                            Section(feed.title) {
                                ForEach(Array(feed.items.enumerated()), id: \.offset) { _, item in
                                    NewsRow(item: item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .refreshable { await load() }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        async let feedTask = try? await authVM.client.news.feed(platform: .mobile)
        async let eventsTask = try? await authVM.client.events.events(page: 0, size: 20)
        let (loadedFeed, loadedEvents) = await (feedTask, eventsTask)
        feed = loadedFeed
        events = loadedEvents?.content ?? []
        errorMessage = loadedFeed == nil && loadedEvents == nil
            ? String(localized: "Couldn't reach Vélo'v's news feed.")
            : nil
    }
}

private struct NewsRow: View {
    let item: RSSFeed.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(.subheadline.weight(.semibold))
            if let description = item.description, !description.isEmpty {
                Text(plainText(description))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            HStack(spacing: 6) {
                if let publishedDate = item.publishedDate {
                    Text(publishedDate)
                }
                if let link = item.link, let url = URL(string: link) {
                    Link("Read more", destination: url)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// RSS descriptions arrive as HTML fragments; the tags would otherwise be shown literally.
    private func plainText(_ html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct EventRow: View {
    let event: DisplayableEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if event.highPriority == true {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            if let body = bodyText {
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let stationLabel = event.stations.first?.label {
                Label(stationLabel, systemImage: "mappin.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let startDate = event.startDate {
                Text(dateRangeText(from: startDate, to: event.endDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if let title = event.content?.title, !title.isEmpty { return title }
        return event.type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private var bodyText: String? {
        event.content?.description.flatMap { $0.isEmpty ? nil : $0 }
    }

    private func dateRangeText(from start: Date, to end: Date?) -> String {
        let startText = start.formatted(date: .abbreviated, time: .shortened)
        guard let end else { return String(localized: "From \(startText)") }
        return "\(startText) – \(end.formatted(date: .abbreviated, time: .shortened))"
    }
}
