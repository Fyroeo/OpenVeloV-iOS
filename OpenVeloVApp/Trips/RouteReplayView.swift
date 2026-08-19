import CoreLocation
import MapKit
import SwiftUI

/// Precomputes cumulative distances along a route so a fractional progress (0...1) maps to a
/// point and to the traveled sub-path at a steady speed, regardless of how the trace was thinned.
struct RoutePlayback {
    let coordinates: [CLLocationCoordinate2D]
    private let cumulative: [Double]
    let totalDistance: Double

    init(_ coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        var running: [Double] = coordinates.isEmpty ? [] : [0]
        var total = 0.0
        if coordinates.count > 1 {
            for index in 1..<coordinates.count {
                total += Self.location(coordinates[index - 1]).distance(from: Self.location(coordinates[index]))
                running.append(total)
            }
        }
        cumulative = running
        totalDistance = total
    }

    func point(at fraction: Double) -> CLLocationCoordinate2D? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count > 1, totalDistance > 0 else { return first }
        let target = max(0, min(1, fraction)) * totalDistance
        guard let upper = cumulative.firstIndex(where: { $0 >= target }), upper > 0 else { return first }
        let lower = upper - 1
        let span = cumulative[upper] - cumulative[lower]
        let t = span > 0 ? (target - cumulative[lower]) / span : 0
        return Self.interpolate(coordinates[lower], coordinates[upper], t)
    }

    func traveled(upTo fraction: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1, totalDistance > 0 else { return coordinates }
        let target = max(0, min(1, fraction)) * totalDistance
        var result: [CLLocationCoordinate2D] = []
        for (index, distance) in cumulative.enumerated() where distance <= target {
            result.append(coordinates[index])
        }
        if let head = point(at: fraction) {
            if let last = result.last, last.latitude != head.latitude || last.longitude != head.longitude {
                result.append(head)
            } else if result.isEmpty {
                result.append(head)
            }
        }
        return result
    }

    var boundingRegion: MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.6, 0.004),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.6, 0.004)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func location(_ coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private static func interpolate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }
}

/// Plays a recorded ride back on the map: a bike marker rides the traveled portion of the route
/// while the rest stays faded, with play/pause and a scrubber.
struct RouteReplayView: View {
    let coordinates: [CLLocationCoordinate2D]
    /// The ride's real duration, used only to label the scrubber; the replay itself runs in
    /// `replayDuration` seconds regardless.
    var tripDuration: TimeInterval?
    var isElectric: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let playback: RoutePlayback
    private let replayDuration: Double = 10

    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var cameraPosition: MapCameraPosition
    @State private var tickerTask: Task<Void, Never>?

    init(coordinates: [CLLocationCoordinate2D], tripDuration: TimeInterval? = nil, isElectric: Bool = false) {
        self.coordinates = coordinates
        self.tripDuration = tripDuration
        self.isElectric = isElectric
        let playback = RoutePlayback(coordinates)
        self.playback = playback
        _cameraPosition = State(initialValue: .region(playback.boundingRegion ?? MKCoordinateRegion(
            center: coordinates.first ?? CLLocationCoordinate2D(latitude: 45.75, longitude: 4.85),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                controls
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear { tickerTask?.cancel() }
    }

    private var map: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            let traveled = playback.traveled(upTo: progress)
            if traveled.count > 1 {
                MapPolyline(coordinates: traveled)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }

            if let start = coordinates.first {
                Marker("Start", systemImage: "flag.fill", coordinate: start).tint(.green)
            }
            if let end = coordinates.last {
                Marker("End", systemImage: "flag.checkered", coordinate: end).tint(.red)
            }

            if let current = playback.point(at: progress) {
                Annotation("", coordinate: current) {
                    Image(systemName: isElectric ? "bolt.fill" : "bicycle")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(isElectric ? Color.green : Color.red, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(radius: 3)
                }
                .annotationTitles(.hidden)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Text(elapsedLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(distanceLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $progress, in: 0...1) { editing in
                if editing { pause() }
            }
            .tint(.accentColor)

            HStack(spacing: 28) {
                Button { restart() } label: {
                    Image(systemName: "gobackward").font(.title2)
                }
                .accessibilityLabel("Restart")

                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }
            .padding(.bottom, 8)
        }
        .padding(16)
        .padding(.bottom, 20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var elapsedLabel: String {
        guard let tripDuration else { return "\(Int(progress * 100))%" }
        let elapsed = tripDuration * progress
        return durationFormatter.string(from: elapsed) ?? "0s"
    }

    private var distanceLabel: String {
        let travelled = playback.totalDistance * progress
        if travelled >= 1000 {
            return (travelled / 1000).formatted(.number.precision(.fractionLength(1))) + " km"
        }
        return "\(Int(travelled)) m"
    }

    // MARK: - Playback control

    private func togglePlay() {
        isPlaying ? pause() : play()
    }

    private func play() {
        if progress >= 1 { progress = 0 }
        isPlaying = true
        tickerTask?.cancel()
        tickerTask = Task { @MainActor in
            let step = 1.0 / (replayDuration * 30) // ~30 fps
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(nanoseconds: 33_000_000)
                if Task.isCancelled || !isPlaying { break }
                progress = min(1, progress + step)
                if progress >= 1 { isPlaying = false; break }
            }
        }
    }

    private func pause() {
        isPlaying = false
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func restart() {
        progress = 0
        play()
    }
}
