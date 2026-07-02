import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class XcodeDiagnosticsTests: XCTestCase {

    private var tempRoot: URL?

    override func setUpWithError() throws {
        tempRoot = try FixtureTree.createTemp { _ in
            // Empty root — individual tests build their own subtrees.
        }
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        tempRoot = nil
    }

    // MARK: - Clean / heavy fixtures

    func testCleanFixtureProducesNoIssues() async throws {
        let root = try FixtureTree.createCleanXcodeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let developer = root.appendingPathComponent("Library/Developer/Xcode")
        let simulator = root.appendingPathComponent("Library/Developer/CoreSimulator")
        let diagnostics = XcodeDiagnostics(
            developerDirectory: developer,
            coreSimulatorDirectory: simulator
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 0, "Clean fixture should produce no issues. Got: \(issues.map(\.title))")
    }

    func testHeavyFixtureTriggersAllScans() async throws {
        let root = try FixtureTree.createHeavyXcodeFixture()
        defer { try? FileManager.default.removeItem(at: root) }

        let developer = root.appendingPathComponent("Library/Developer/Xcode")
        let simulator = root.appendingPathComponent("Library/Developer/CoreSimulator")
        let diagnostics = XcodeDiagnostics(
            developerDirectory: developer,
            coreSimulatorDirectory: simulator
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())

        // Expected: DerivedData, Archives, Simulator Caches, iOS DeviceSupport.
        let titles = Set(issues.map(\.title))
        XCTAssertTrue(titles.contains("Xcode DerivedData"))
        XCTAssertTrue(titles.contains("Xcode Archives"))
        XCTAssertTrue(titles.contains("Simulator Caches"))
        XCTAssertTrue(titles.contains("iOS DeviceSupport"))
    }

    // MARK: - Per-scan isolation

    func testDerivedDataLargeEnoughTriggersIssue() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 5_000_000_000,  // 5 GB
            archivesBytes: 0,
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Xcode DerivedData")
        XCTAssertEqual(issues[0].severity, .warning)
        // FixtureTree splits the target across 3 projects × 4 files via integer
        // division, which can lose up to ~12 bytes to rounding. Use an
        // accuracy of 1_000 to keep the assertion robust. Unwrap the
        // optional first because XCTAssertEqual's accuracy: variant
        // requires matching Int overloads.
        let savings = issues[0].estimatedSavingsBytes ?? 0
        XCTAssertEqual(Int(savings), 5_000_000_000, accuracy: 1_000)
        XCTAssertTrue(issues[0].fixAvailable)
        XCTAssertNotNil(issues[0].remediationText)
    }

    func testDerivedDataHugePromotesToCritical() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 15_000_000_000,  // 15 GB → critical threshold (10 GB)
            archivesBytes: 0,
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].severity, .critical,
            "DerivedData ≥ 10 GB should be critical")
    }

    func testDerivedDataBelowThresholdProducesNoIssue() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 500_000_000,  // 500 MB → below 1 GB threshold
            archivesBytes: 0,
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertTrue(issues.isEmpty, "500 MB DerivedData should not trigger (threshold is 1 GB)")
    }

    func testArchivesHasFixAvailableFalse() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 0,
            archivesBytes: 3_000_000_000,  // 3 GB
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Xcode Archives")
        XCTAssertFalse(issues[0].fixAvailable, "Archives require manual deletion via Xcode Organizer")
        XCTAssertNotNil(issues[0].remediationText)
    }

    func testDeviceSupportIssueCarriesPlatformName() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 0,
            archivesBytes: 0,
            deviceSupportBytes: 2_500_000_000,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "iOS DeviceSupport")
        XCTAssertTrue(issues[0].remediationText?.contains("iOS") ?? false)
    }

    func testSimulatorCachesTriggersWhenLarge() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 0,
            archivesBytes: 0,
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 2_000_000_000  // 2 GB
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let diagnostics = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Simulator Caches")
        XCTAssertEqual(issues[0].severity, .warning)
    }

    // MARK: - Threshold configurability

    func testCustomThresholdChangesWhatTriggers() async throws {
        let root = try FixtureTree.createXcodeFixture(
            derivedDataBytes: 1_500_000_000,  // 1.5 GB
            archivesBytes: 0,
            deviceSupportBytes: 0,
            coreSimulatorCachesBytes: 0
        )
        defer { try? FileManager.default.removeItem(at: root) }

        // Default threshold (1 GB) → triggers.
        let defaultDiag = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator")
        )
        let defaultIssues = try await defaultDiag.diagnose(context: DiagnosticsContext())
        XCTAssertEqual(defaultIssues.count, 1)

        // Custom 2 GB threshold → does not trigger.
        let strictDiag = XcodeDiagnostics(
            developerDirectory: root.appendingPathComponent("Library/Developer/Xcode"),
            coreSimulatorDirectory: root.appendingPathComponent("Library/Developer/CoreSimulator"),
            significantSizeThreshold: 2_000_000_000
        )
        let strictIssues = try await strictDiag.diagnose(context: DiagnosticsContext())
        XCTAssertTrue(strictIssues.isEmpty)
    }

    // MARK: - Missing paths

    func testMissingDeveloperDirectoryProducesNoIssues() async throws {
        let missing = tempRoot!.appendingPathComponent("does-not-exist")
        let diagnostics = XcodeDiagnostics(
            developerDirectory: missing,
            coreSimulatorDirectory: missing
        )

        let issues = try await diagnostics.diagnose(context: DiagnosticsContext())
        XCTAssertTrue(issues.isEmpty,
            "Missing directories should produce zero issues, not crash")
    }
}
