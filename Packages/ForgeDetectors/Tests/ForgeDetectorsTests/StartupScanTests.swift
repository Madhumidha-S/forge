import XCTest
@testable import ForgeDetectors
import ForgeCore

final class StartupScanTests: XCTestCase {
    struct StubDetector: ToolDetector {
        let id: ToolID
        let displayName: String
        let version: SemVer

        func detect() async throws -> DetectionResult {
            DetectionResult(
                toolId: id,
                version: version,
                installPath: "/usr/bin/\(id.rawValue)",
                healthChecks: [HealthCheck(name: "executable", passed: true)]
            )
        }
    }

    func testRegisterThreeDetectorsAndScanAllReturnsThreeResults() async throws {
        let registry = DetectorRegistry()
        await registry.register(StubDetector(id: .node, displayName: "Node", version: SemVer(major: 20, minor: 0, patch: 0)))
        await registry.register(StubDetector(id: .python, displayName: "Python", version: SemVer(major: 3, minor: 12, patch: 0)))
        await registry.register(StubDetector(id: .git, displayName: "Git", version: SemVer(major: 2, minor: 45, patch: 0)))

        let results = await registry.scanAll()
        XCTAssertEqual(results.count, 3)
    }
}
