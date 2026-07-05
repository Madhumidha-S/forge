import Foundation
import Combine
import SwiftUI

/// User preferences for the Forge app. Backed by `@AppStorage` so each
/// setting writes through to `UserDefaults.standard` and survives app
/// relaunches. Per the architecture doc's resolved decision #5, settings
/// use `@AppStorage` directly rather than SwiftData — they're tiny,
/// primitive values that don't need a relational store.
///
/// The store is `@MainActor` because `@AppStorage` integrates with the
/// SwiftUI view system, and the SettingsView binds to these properties
/// via `$settings.<key>`. All mutations from views happen on the main
/// actor.
@MainActor
public final class SettingsStore: ObservableObject {
    /// Whether Forge should register as a login item. (Behavior deferred
    /// to a future phase; this only persists the preference.)
    @AppStorage("settings.launchAtLogin") public var launchAtLogin: Bool = false

    /// Whether Forge should check for new versions automatically.
    @AppStorage("settings.autoCheckUpdates") public var autoCheckUpdates: Bool = true

    /// How often (in minutes) Forge should re-run the environment scan.
    /// Allowed values: 15, 30, 60, 120, 360, 1440. The View enforces
    /// the allowed set via `Picker` tags.
    @AppStorage("settings.refreshIntervalMinutes") public var refreshIntervalMinutes: Int = 60

    /// Whether the diagnostics engine should run immediately on launch.
    @AppStorage("settings.analyzeOnLaunch") public var analyzeOnLaunch: Bool = true

    /// Whether the diagnostics scan should skip tools that aren't
    /// installed on this machine.
    @AppStorage("settings.skipUninstalled") public var skipUninstalled: Bool = true

    /// Threshold (in GB) below which a cleanup candidate isn't surfaced
    /// to the user. Allowed values: 0.5, 1.0, 5.0, 10.0.
    @AppStorage("settings.reclaimThresholdGB") public var reclaimThresholdGB: Double = 1.0

    public init() {}
}
