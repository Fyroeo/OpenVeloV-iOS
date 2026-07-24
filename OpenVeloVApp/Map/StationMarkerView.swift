import SwiftUI

/// A small pill-shaped pin. It shows a count for bikes or docks, based on `numberMode`.
/// The pin color shows the current availability level.
struct StationMarkerView: View {
    let station: MapStation
    let numberMode: MapNumberMode

    private var count: Int { numberMode.count(for: station) }

    private var tint: Color {
        guard numberMode.isAvailable(at: station) else { return .gray }
        return numberMode.availability(for: station).color
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint, in: Capsule())
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(tint)
                .offset(y: -4)
        }
    }
}
