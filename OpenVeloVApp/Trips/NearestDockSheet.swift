import MapKit
import SwiftUI

struct NearestDockSheet: View {
    let station: MapStation
    let userLocation: UserLocation?
    let onDirections: () -> Void
    let onShowOnMap: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var distance: Double? { station.distance(from: userLocation) }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Nearest free dock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(station.name)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            HStack(spacing: 0) {
                metric(value: "\(station.docksAvailable)", label: "Free docks", systemImage: "parkingsign", tint: .accentColor)
                if let distance {
                    Divider().frame(height: 38)
                    metric(value: MapStation.distanceText(distance), label: "Away", systemImage: "location", tint: .secondary)
                    if let walkingTime = MapStation.walkingTimeText(for: distance) {
                        Divider().frame(height: 38)
                        metric(value: walkingTime, label: "On foot", systemImage: "figure.walk", tint: .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            Map(initialPosition: .region(
                MKCoordinateRegion(center: station.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
            )) {
                Marker(station.name, systemImage: "parkingsign", coordinate: station.coordinate)
                    .tint(Color.accentColor)
                UserAnnotation()
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Button(action: onDirections) {
                    Label("Walking Directions", systemImage: "figure.walk")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                Button(action: onShowOnMap) {
                    Label("Show on Map", systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .presentationDetents([.height(470)])
        .presentationDragIndicator(.visible)
    }

    private func metric(value: String, label: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
