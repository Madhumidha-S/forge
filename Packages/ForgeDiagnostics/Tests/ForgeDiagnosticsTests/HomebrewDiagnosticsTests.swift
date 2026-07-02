import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class HomebrewDiagnosticsTests: XCTestCase {

    private var tempRoot: URL?

    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        tempRoot = nil
    }

    func testCleanInstallProducesNoIssues() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.brewInfo(packages: [
            (name: "git", outdated: false, installedOnRequest: true, pouredFromBottle: true)
        ]))
        let issues = try await HomebrewDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.isEmpty)
    }

    func testOutdatedPackagesTriggersWarning() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.brewInfo(packages: [
            (name: "git", outdated: true, installedOnRequest: true, pouredFromBottle: true),
            (name: "curl", outdated: true, installedOnRequest: true, pouredFromBottle: true)
        ]))
        let issues = try await HomebrewDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Outdated Homebrew packages")
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testOrphanPackagesTriggersInfo() async throws {
        // installed_on_request=false + poured_from_bottle=true → orphan
        let runner = FakeCommandRunner(script: FakeCommandRunner.brewInfo(packages: [
            (name: "openssl@3", outdated: false, installedOnRequest: false, pouredFromBottle: true),
            (name: "readline", outdated: false, installedOnRequest: false, pouredFromBottle: true)
        ]))
        let issues = try await HomebrewDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Orphan Homebrew packages")
        XCTAssertEqual(issues[0].severity, .info)
    }

    func testLargeCacheTriggersWarning() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file("Caches/git-2.45.0.tar.gz", size: 1_500_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeCommandRunner(script: FakeCommandRunner.brewInfo(packages: []))
        let cacheURL = root.appendingPathComponent("Caches")
        let diag = HomebrewDiagnostics(cacheDirectory: cacheURL)
        let issues = try await diag.diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Homebrew cache")
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testAllThreeIssuesWhenAllTrigger() async throws {
        let root = try FixtureTree.createTemp { builder in
            builder.file("Caches/big.tar.gz", size: 1_500_000_000)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeCommandRunner(script: FakeCommandRunner.brewInfo(packages: [
            (name: "git", outdated: true, installedOnRequest: true, pouredFromBottle: true),
            (name: "openssl@3", outdated: false, installedOnRequest: false, pouredFromBottle: true)
        ]))
        let diag = HomebrewDiagnostics(cacheDirectory: root.appendingPathComponent("Caches"))
        let issues = try await diag.diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 3)
    }
}
