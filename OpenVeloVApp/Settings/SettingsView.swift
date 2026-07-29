import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Warn before free time ends", isOn: $settings.isRideEndingAlertEnabled)

                    if settings.isRideEndingAlertEnabled {
                        Picker("Included time", selection: $settings.freeRideMinutes) {
                            ForEach(AppSettings.freeRideOptions, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        Picker("Warn me", selection: $settings.rideEndingLeadMinutes) {
                            ForEach(AppSettings.leadTimeOptions, id: \.self) { minutes in
                                Text("\(minutes) min before").tag(minutes)
                            }
                        }
                    }
                } header: {
                    Text("Ride Alerts")
                } footer: {
                    Text("Vélo'v includes a set amount of ride time in each subscription, and no endpoint reports how much yours has — set it here so the warning arrives at the right moment. Long-term subscriptions usually include 30 minutes.")
                }

                Section {
                    Toggle("Record my route", isOn: $settings.isRouteRecordingEnabled)
                } header: {
                    Text("Ride History")
                } footer: {
                    Text("Records your ride's path and uploads it to your Vélo'v account when you dock, so past rides show a real route on the map instead of just the start and end stations. Uses GPS in the background while you're riding.")
                }

                Section {
                    Toggle("Tell me when I arrive", isOn: $settings.isBookingArrivalAlertEnabled)
                } header: {
                    Text("Booking Holds")
                } footer: {
                    Text("Notifies you when you reach the station holding your bike, so you can unlock without opening the app first. Uses GPS in the background for as long as the hold lasts.")
                }

                if settings.needsBackgroundLocation && !locationManager.isAuthorized {
                    Section {
                        Label(
                            "These need location access, which is currently off. Turn it on in Settings › OpenVeloV › Location.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)

                        Button("Open iOS Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.shortVersionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("OpenVeloV is an independent, open-source client for Lyon's Vélo'v. It is not affiliated with, endorsed by, or supported by JCDecaux or Grand Lyon.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

extension Bundle {
    var shortVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
