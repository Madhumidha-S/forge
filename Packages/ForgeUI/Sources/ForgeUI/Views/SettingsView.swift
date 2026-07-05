import SwiftUI
import ForgeCore
import ForgeDesign

/// Settings screen — app preferences backed by `@AppStorage` per the
/// architecture doc's resolved decision #5.
///
/// Four sections matching the wireframe:
/// - General: launch-at-login, auto-update, refresh interval
/// - Diagnostics: analyze-on-launch, skip-uninstalled
/// - Storage: reclaim threshold
/// - About: version, build, open-source caption
///
/// All values bind directly to `SettingsStore`'s `@AppStorage`-backed
/// properties, so toggling a control writes through to
/// `UserDefaults.standard` and survives app relaunches.
public struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

    public init() {}

    public var body: some View {
        Form {
            generalSection
            diagnosticsSection
            storageSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch Forge at login", isOn: $settings.launchAtLogin)
            Toggle("Check for updates automatically", isOn: $settings.autoCheckUpdates)
            Picker("Refresh interval", selection: $settings.refreshIntervalMinutes) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
                Text("2 hours").tag(120)
                Text("6 hours").tag(360)
                Text("24 hours").tag(1440)
            }
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            Toggle("Analyze on launch", isOn: $settings.analyzeOnLaunch)
            Toggle("Skip tools not installed", isOn: $settings.skipUninstalled)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Storage") {
            Picker("Reclaim threshold", selection: $settings.reclaimThresholdGB) {
                Text("500 MB").tag(0.5)
                Text("1 GB").tag(1.0)
                Text("5 GB").tag(5.0)
                Text("10 GB").tag(10.0)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.4.0")
            LabeledContent("Build", value: "dev")
            Text("Forge is an open-source developer environment manager.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
