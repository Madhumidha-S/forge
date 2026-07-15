import SwiftUI
import AppKit
import ForgeCore
import ForgeDesign

/// Settings screen — native macOS System Settings style.
///
/// Uses `.formStyle(.grouped)` with the macOS-native row padding and
/// section styling. The "About Forge" entry is intentionally absent —
/// the standard macOS About panel is opened from the app menu (Forge ▸
/// About Forge), which is the native idiom. No manual Version/Build
/// rows inside the form.
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
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 480, minHeight: 460)
    }

    // MARK: - General

    private var generalSection: some View {
        Section {
            Toggle("Launch Forge at login", isOn: $settings.launchAtLogin)
                .help("Automatically open Forge when you sign in to your Mac.")
            Toggle("Check for updates automatically", isOn: $settings.autoCheckUpdates)
                .help("Periodically check for new versions of Forge.")
            Picker("Refresh interval", selection: $settings.refreshIntervalMinutes) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
                Text("2 hours").tag(120)
                Text("6 hours").tag(360)
                Text("24 hours").tag(1440)
            }
            .help("How often Forge should re-scan your environment.")
        } header: {
            Text("General")
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section {
            Toggle("Analyze on launch", isOn: $settings.analyzeOnLaunch)
                .help("Run a full diagnostic scan when Forge opens.")
            Toggle("Skip tools not installed", isOn: $settings.skipUninstalled)
                .help("Don't surface findings for tools that aren't on this Mac.")
        } header: {
            Text("Diagnostics")
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section {
            Picker("Reclaim threshold", selection: $settings.reclaimThresholdGB) {
                Text("500 MB").tag(0.5)
                Text("1 GB").tag(1.0)
                Text("5 GB").tag(5.0)
                Text("10 GB").tag(10.0)
            }
            .help("Cleanup opportunities smaller than this won't be surfaced.")
        } header: {
            Text("Storage")
        }
    }
}
