import XCTest
@testable import ForgeUI

/// Tests for the `@AppStorage`-backed `SettingsStore` used by the
/// Settings screen.
///
/// The store is `@MainActor`, so all test methods must also be
/// `@MainActor` to satisfy the isolation requirement. Each test resets
/// the relevant `UserDefaults` keys in `setUp` and `tearDown` so the
/// shared `UserDefaults.standard` suite doesn't leak state between
/// tests.
@MainActor
final class SettingsStoreTests: XCTestCase {
    private let defaultsKeys: [String] = [
        "settings.launchAtLogin",
        "settings.autoCheckUpdates",
        "settings.refreshIntervalMinutes",
        "settings.analyzeOnLaunch",
        "settings.skipUninstalled",
        "settings.reclaimThresholdGB"
    ]

    override func setUp() {
        super.setUp()
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    private func resetDefaults() {
        let defaults = UserDefaults.standard
        for key in defaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Test 1: defaults match the wireframe

    func testDefaultsMatchWireframe() {
        let store = SettingsStore()

        XCTAssertFalse(store.launchAtLogin, "launchAtLogin should default to false")
        XCTAssertTrue(store.autoCheckUpdates, "autoCheckUpdates should default to true")
        XCTAssertEqual(store.refreshIntervalMinutes, 60, "refreshIntervalMinutes should default to 60")
        XCTAssertTrue(store.analyzeOnLaunch, "analyzeOnLaunch should default to true")
        XCTAssertTrue(store.skipUninstalled, "skipUninstalled should default to true")
        XCTAssertEqual(store.reclaimThresholdGB, 1.0, "reclaimThresholdGB should default to 1.0")
    }

    // MARK: - Test 2: setting launchAtLogin persists

    func testSettingLaunchAtLoginPersists() {
        let store = SettingsStore()
        store.launchAtLogin = true
        XCTAssertTrue(store.launchAtLogin)

        // A fresh store reads from the same UserDefaults backing, so
        // the new value should come back.
        let other = SettingsStore()
        XCTAssertTrue(other.launchAtLogin)
    }

    // MARK: - Test 3: changing refreshIntervalMinutes persists

    func testChangingRefreshIntervalPersists() {
        let store = SettingsStore()
        store.refreshIntervalMinutes = 30
        XCTAssertEqual(store.refreshIntervalMinutes, 30)

        let other = SettingsStore()
        XCTAssertEqual(other.refreshIntervalMinutes, 30)
    }
}
