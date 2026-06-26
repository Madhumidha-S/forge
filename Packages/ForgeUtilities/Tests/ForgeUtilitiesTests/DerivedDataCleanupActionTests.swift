import XCTest
@testable import ForgeUtilities
@testable import ForgeCore

final class DerivedDataCleanupActionTests: XCTestCase {
    private var fixtureRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixtureRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ForgeUtilitiesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let fixtureRoot {
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
        fixtureRoot = nil
        try super.tearDownWithError()
    }

    func testDryRunReturnsEmptyReportForMissingDirectory() async throws {
        let missing = fixtureRoot.appendingPathComponent("does-not-exist", isDirectory: true)
        let action = DerivedDataCleanupAction(rootURL: missing)
        let report = try await action.dryRun()
        XCTAssertEqual(report.candidatePaths.count, 0)
        XCTAssertEqual(report.totalReclaimableBytes, 0)
        XCTAssertEqual(report.target, "Xcode DerivedData")
    }

    func testDryRunSumsKnownSizesAcrossThreeSubdirectories() async throws {
        // Create three fake DerivedData-style directories with known file sizes.
        let dir1 = fixtureRoot.appendingPathComponent("ProjectA-abc123", isDirectory: true)
        let dir2 = fixtureRoot.appendingPathComponent("ProjectB-def456", isDirectory: true)
        let dir3 = fixtureRoot.appendingPathComponent("ProjectC-ghi789", isDirectory: true)
        for dir in [dir1, dir2, dir3] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try Data(count: 1024).write(to: dir1.appendingPathComponent("a.bin"))
        try Data(count: 2048).write(to: dir1.appendingPathComponent("b.bin"))
        try Data(count: 4096).write(to: dir2.appendingPathComponent("c.bin"))
        try Data(count: 0).write(to: dir3.appendingPathComponent("empty.txt"))  // 0-byte files should count as 0
        try Data(count: 8192).write(to: dir3.appendingPathComponent("d.bin"))

        let action = DerivedDataCleanupAction(rootURL: fixtureRoot)
        let report = try await action.dryRun()

        XCTAssertEqual(report.candidatePaths.count, 3, "expected exactly 3 candidate directories")
        XCTAssertEqual(report.totalReclaimableBytes, Int64(1024 + 2048 + 4096 + 0 + 8192))
        XCTAssertEqual(report.target, "Xcode DerivedData")
        // Paths should be sorted; verify ProjectA < ProjectB < ProjectC lexicographically.
        XCTAssertTrue(report.candidatePaths[0].lastPathComponent.hasPrefix("ProjectA"))
        XCTAssertTrue(report.candidatePaths[2].lastPathComponent.hasPrefix("ProjectC"))
    }

    func testDryRunSkipsSymbolicLinks() async throws {
        let dir = fixtureRoot.appendingPathComponent("ProjectWithSymlink-xyz", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Real file
        try Data(count: 100).write(to: dir.appendingPathComponent("real.bin"))
        // Symlink pointing to a large file outside the fixture
        let outsideFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("outside-\(UUID().uuidString).bin")
        try Data(count: 999_999).write(to: outsideFile)
        defer { try? FileManager.default.removeItem(at: outsideFile) }
        try FileManager.default.createSymbolicLink(
            at: dir.appendingPathComponent("link.bin"),
            withDestinationURL: outsideFile
        )

        let action = DerivedDataCleanupAction(rootURL: fixtureRoot)
        let report = try await action.dryRun()

        XCTAssertEqual(report.candidatePaths.count, 1)
        XCTAssertEqual(report.totalReclaimableBytes, 100, "symlink target must not be counted")
    }

    func testActionIsTrashOnly() {
        let action = DerivedDataCleanupAction(rootURL: fixtureRoot)
        // TrashOnly is a marker protocol; the type-check confirms conformance.
        let _: any TrashOnly = action
        XCTAssertTrue(action is any TrashOnly)
    }
}
