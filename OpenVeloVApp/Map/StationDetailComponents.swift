import SwiftUI

struct StatTile: View {
    let systemImage: String
    let tint: Color
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct LegendItem: View {
    let color: Color
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

/// Stands the mechanical, electric and free-dock counts don't account for are drawn as a grey
/// remainder segment, since a station's capacity can exceed what it currently reports.
struct CapacityBar: View {
    let capacity: Int
    let mechanical: Int
    let electrical: Int
    let free: Int

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                segment(.red, count: mechanical, totalWidth: geometry.size.width)
                segment(.green, count: electrical, totalWidth: geometry.size.width)
                segment(Color(.systemGray3), count: free, totalWidth: geometry.size.width)
                let accounted = mechanical + electrical + free
                if capacity > accounted {
                    segment(Color(.systemGray5), count: capacity - accounted, totalWidth: geometry.size.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 8)
    }

    private func segment(_ color: Color, count: Int, totalWidth: CGFloat) -> some View {
        let fraction = capacity > 0 ? CGFloat(count) / CGFloat(capacity) : 0
        return color.frame(width: totalWidth * fraction)
    }
}
