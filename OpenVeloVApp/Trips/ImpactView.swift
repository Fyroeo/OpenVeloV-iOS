import SwiftUI
import VLSKit

/// "Your Impact" — what the rider's history adds up to.
struct ImpactView: View {
    @StateObject private var viewModel: ImpactViewModel
    @Environment(\.dismiss) private var dismiss

    init(authVM: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: ImpactViewModel(authViewModel: authVM))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.trips.isEmpty {
                    ProgressView("Adding it up…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.trips.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Your Impact", systemImage: "chart.bar.xaxis")
                    } description: {
                        Text(errorMessage)
                    }
                } else if viewModel.rideCount == 0 {
                    ContentUnavailableView(
                        "No Rides Yet",
                        systemImage: "leaf",
                        description: Text("Once you've taken a few rides, this is where the totals show up.")
                    )
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Range", selection: $viewModel.range) {
                    ForEach(ImpactViewModel.Range.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                headlineTiles
                comparedToDrivingCard
                rhythmCard
                bikeTypeCard
            }
            .padding(16)
            .animation(.smooth(duration: 0.25), value: viewModel.range)
        }
    }

    // MARK: - Headline

    private var headlineTiles: some View {
        HStack(spacing: 14) {
            HeadlineTile(
                value: "\(viewModel.rideCount)",
                label: "Rides",
                systemImage: "bicycle",
                tint: .accentColor
            )
            HeadlineTile(
                value: durationText(viewModel.totalDuration),
                label: "In the saddle",
                systemImage: "clock",
                tint: .orange
            )
        }
    }

    // MARK: - Compared to driving

    @ViewBuilder
    private var comparedToDrivingCard: some View {
        let distance = viewModel.serverDistanceKilometres ?? viewModel.estimatedDistanceKilometres
        let isEstimated = viewModel.serverDistanceKilometres == nil

        ImpactCard(spacing: 14) {
            HStack(spacing: 10) {
                iconBadge("leaf.fill", tint: .green)
                Text("Compared to driving")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isEstimated {
                    Text("≈").font(.title.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(distance.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("km").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }

            if viewModel.co2SavedKilograms != nil || viewModel.calories != nil {
                HStack(spacing: 10) {
                    if let co2 = viewModel.co2SavedKilograms {
                        metricChip("CO₂ avoided", value: "\(co2.formatted(.number.precision(.fractionLength(1)))) kg", systemImage: "smoke.fill", tint: .teal)
                    }
                    if let calories = viewModel.calories {
                        metricChip("Calories burned", value: "\(calories)", systemImage: "flame.fill", tint: .orange)
                    }
                }
            }

            if isEstimated && viewModel.didAttemptServerStats {
                Text("Vélo'v didn't return CO₂, calorie, or distance figures for this account. The distance above is estimated from your total riding time at an average city pace, not measured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - When you ride

    private var rhythmCard: some View {
        ImpactCard(spacing: 16) {
            cardTitle("When you ride", systemImage: "calendar")
            weekdayChart
            VStack(spacing: 0) {
                if let busiestHour = viewModel.busiestHour {
                    statRow("Most common start", value: hourLabel(busiestHour))
                    Divider()
                }
                statRow("Average ride", value: durationText(viewModel.averageDuration))
                if let longest = viewModel.longestTrip, let start = longest.startDateTime, let end = longest.endDateTime {
                    Divider()
                    statRow("Longest ride", value: durationText(end.timeIntervalSince(start)))
                }
            }
        }
    }

    private var weekdayChart: some View {
        let data = viewModel.ridesByWeekday
        let maximum = max(data.map(\.count).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                let isPeak = entry.count == maximum && entry.count > 0
                VStack(spacing: 6) {
                    Text(entry.count > 0 ? "\(entry.count)" : " ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isPeak ? Color.accentColor : .secondary)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(barFill(isPeak: isPeak, hasRides: entry.count > 0))
                        .frame(height: max(6, CGFloat(entry.count) / CGFloat(maximum) * 78))
                    Text(entry.symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rides by weekday: " + data.map { "\($0.symbol) \($0.count)" }.joined(separator: ", "))
    }

    private func barFill(isPeak: Bool, hasRides: Bool) -> AnyShapeStyle {
        guard hasRides else { return AnyShapeStyle(Color(.systemGray5)) }
        let top = isPeak ? Color.accentColor : Color.accentColor.opacity(0.55)
        return AnyShapeStyle(LinearGradient(colors: [top, top.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: - Bike type

    private var bikeTypeCard: some View {
        let total = max(viewModel.rideCount, 1)
        let electricFraction = Double(viewModel.electricCount) / Double(total)
        return ImpactCard(spacing: 14) {
            cardTitle("Bike type", systemImage: "bicycle")
            GeometryReader { geometry in
                HStack(spacing: 3) {
                    Capsule().fill(Color.green)
                        .frame(width: max(0, geometry.size.width * electricFraction - 1.5))
                    Capsule().fill(Color.red)
                }
            }
            .frame(height: 12)

            HStack(spacing: 18) {
                legendDot(.green, "\(viewModel.electricCount) electric", systemImage: "bolt.fill")
                legendDot(.red, "\(viewModel.mechanicalCount) mechanical", systemImage: "bicycle")
                Spacer()
            }
            .font(.caption.weight(.medium))
        }
    }

    // MARK: - Small components

    private func cardTitle(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func iconBadge(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func metricChip(_ label: LocalizedStringKey, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.semibold))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func statRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private func legendDot(_ color: Color, _ label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .foregroundStyle(color)
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(.dateTime.hour())
    }
}
