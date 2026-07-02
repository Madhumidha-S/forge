import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class AndroidStudioDiagnosticsTests: XCTestCase {

    private var tempRoot: URL?

    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        tempRoot = nil
    }

    func testAllMissingProducesNoIssues() async throws {
        let root = try FixtureTree.createTemp { _ in }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = AndroidStudioDiagnostics(
            sdkDirectory: root.appendingPathComponent("Library/Android/sdk"),
            gradleCacheDirectory: root.appendingPathComponent(".gradle/caches"),
            emulatorDirectory: root.appendingPathComponent(".android/avd")
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertTrue(issues.isEmpty)
    }

    func testLargeSDKTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file("Library/Android/sdk/platforms/android-34/build.prop", size: 2_500_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = AndroidStudioDiagnostics(
            sdkDirectory: root.appendingPathComponent("Library/Android/sdk"),
            gradleCacheDirectory: nil,
            emulatorDirectory: nil
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Android SDK")
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testLargeGradleCacheTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".gradle/caches/modules-2/cache.bin", size: 3_000_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = AndroidStudioDiagnostics(
            sdkDirectory: nil,
            gradleCacheDirectory: root.appendingPathComponent(".gradle/caches"),
            emulatorDirectory: nil
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Gradle cache")
    }

    func testLargeEmulatorTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file(".android/avd/Pixel_7_API_34.avd/sdcard.img", size: 2_000_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let diag = AndroidStudioDiagnostics(
            sdkDirectory: nil,
            gradleCacheDirectory: nil,
            emulatorDirectory: root.appendingPathComponent(".android/avd")
        )
        let issues = try await diag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Android emulator storage")
    }
}
