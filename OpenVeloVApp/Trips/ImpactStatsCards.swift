import SwiftUI

/// A single headline figure for the records card.
struct ImpactRecord: Identifiable {
    let id = UUID()
    let label: LocalizedStringKey
    let value: String
    let systemImage: String
    let tint: Color
}

// MARK: - Streak

struct StreakCard: View {
    let currentWeeks: Int
    let longestWeeks: Int

    var body: some View {
        ImpactCard(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(streakGradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text("Riding streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(currentWeeks)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(currentWeeks > 0 ? AnyShapeStyle(streakGradient) : AnyShapeStyle(Color.secondary))
                    .contentTransition(.numericText())
                Text(currentWeeks == 1 ? "week in a row" : "weeks in a row")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: LocalizedStringKey {
        if currentWeeks == 0 {
            return "Ride this week to start a new streak. Your best is \(longestWeeks) weeks."
        }
        return "Your best streak is \(longestWeeks) weeks."
    }

    private var streakGradient: LinearGradient {
        LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Records

struct RecordsCard: View {
    let records: [ImpactRecord]

    var body: some View {
        ImpactCard(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                Text("Records").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(records) { record in
                    HStack(spacing: 10) {
                        Image(systemName: record.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(record.tint)
                            .frame(width: 28, height: 28)
                            .background(record.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
                            Text(record.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - Monthly chart

struct MonthlyRidesCard: View {
    let data: [(symbol: String, count: Int)]

    var body: some View {
        let maximum = max(data.map(\.count).max() ?? 1, 1)
        ImpactCard(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill").foregroundStyle(.secondary)
                Text("Last 6 months").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, entry in
                    VStack(spacing: 6) {
                        Text(entry.count > 0 ? "\(entry.count)" : " ")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(barFill(hasRides: entry.count > 0))
                            .frame(height: max(6, CGFloat(entry.count) / CGFloat(maximum) * 90))
                        Text(entry.symbol).font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rides by month: " + data.map { "\($0.symbol) \($0.count)" }.joined(separator: ", "))
        }
    }

    private func barFill(hasRides: Bool) -> AnyShapeStyle {
        guard hasRides else { return AnyShapeStyle(Color(.systemGray5)) }
        return AnyShapeStyle(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.65)], startPoint: .top, endPoint: .bottom))
    }
}

// MARK: - Achievements

struct AchievementsCard: View {
    let achievements: [Achievement]
    let onSelect: (Achievement) -> Void

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 14)]

    var body: some View {
        ImpactCard(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "medal.fill").foregroundStyle(.yellow)
                Text("Achievements").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(achievements.filter(\.isUnlocked).count)/\(achievements.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(achievements) { achievement in
                    Button { onSelect(achievement) } label: {
                        AchievementBadge(achievement: achievement)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tint.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 56, height: 56)

                if !achievement.isUnlocked {
                    Circle()
                        .trim(from: 0, to: achievement.fractionComplete)
                        .stroke(achievement.tint.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                }

                Image(systemName: achievement.systemImage)
                    .font(.title3)
                    .foregroundStyle(achievement.isUnlocked ? AnyShapeStyle(achievement.tint) : AnyShapeStyle(Color.secondary))
                    .symbolVariant(achievement.isUnlocked ? .none : .none)
            }
            .overlay(alignment: .bottomTrailing) {
                if achievement.isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, .green)
                        .background(Circle().fill(.white).padding(2))
                }
            }

            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .opacity(achievement.isUnlocked ? 1 : 0.85)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        if achievement.isUnlocked {
            return Text("\(achievement.title), unlocked")
        }
        return Text("\(achievement.title), locked, \(achievement.progress) of \(achievement.goal)")
    }
}

struct AchievementDetailSheet: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? achievement.tint.opacity(0.18) : Color(.systemGray5))
                    .frame(width: 120, height: 120)
                if !achievement.isUnlocked {
                    Circle()
                        .trim(from: 0, to: achievement.fractionComplete)
                        .stroke(achievement.tint.opacity(0.7), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                }
                Image(systemName: achievement.systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(achievement.isUnlocked ? AnyShapeStyle(achievement.tint) : AnyShapeStyle(Color.secondary))
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text(achievement.title).font(.title2.bold())
                Text(achievement.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if achievement.isUnlocked {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                VStack(spacing: 8) {
                    ProgressView(value: achievement.fractionComplete)
                        .tint(achievement.tint)
                    Text("\(achievement.progress) / \(achievement.goal)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Color(.tertiarySystemFill), in: Circle())
            }
            .padding()
        }
    }
}
