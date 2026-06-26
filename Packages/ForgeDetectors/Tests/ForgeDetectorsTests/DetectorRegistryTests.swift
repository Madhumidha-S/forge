import XCTest
@testable import ForgeDetectors
import ForgeCore

final class DetectorRegistryTests: XCTestCase {
    struct FakeDetector: ToolDetector {
        let id: ToolID = .git
        let displayName: String = "Fake Git"

        func detect() async throws -> DetectionResult {
            DetectionResult(
                toolId: .git,
                version: SemVer(major: 2, minor: 45, patch: 0),
                installPath: "/usr/bin/git",
                healthChecks: [HealthCheck(name: "executable", passed: true)]
            )
        }
    }

    func testRegisterAndScanAll() async throws {
        let registry = DetectorRegistry()
        await registry.register(FakeDetector())

        let ids = await registry.registeredIDs()
        XCTAssertEqual(ids, [.git])

        let results = await registry.scanAll()
        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.toolId, .git)
        XCTAssertEqual(result.version, SemVer(major: 2, minor: 45, patch: 0))
        XCTAssertEqual(result.installPath, "/usr/bin/git")
        XCTAssertEqual(result.healthChecks.count, 1)
        XCTAssertTrue(result.healthChecks.first?.passed == true)
    }

    struct FlakyDetector: ToolDetector {
        let id: ToolID
        let displayName: String
        let shouldThrow: Bool
        func detect() async throws -> DetectionResult {
            if shouldThrow { throw DetectionError.notFound }
            return DetectionResult(toolId: id, version: SemVer(major: 1, minor: 0, patch: 0))
        }
    }

    func testScanAllFlattensErrors() async throws {
        let registry = DetectorRegistry()
        await registry.register(FlakyDetector(id: .node, displayName: "Node", shouldThrow: false))
        await registry.register(FlakyDetector(id: .python, displayName: "Python", shouldThrow: true))

        let results = await registry.scanAll()
        XCTAssertEqual(results.count, 2)

        let node = try XCTUnwrap(results.first { $0.toolId == .node })
        XCTAssertEqual(node.version, SemVer(major: 1, minor: 0, patch: 0))

        let python = try XCTUnwrap(results.first { $0.toolId == .python })
        XCTAssertNil(python.version)
        XCTAssertEqual(python.healthChecks.first?.passed, false)
    }

    func testScanAllReturnsThreeResultsForThreeRegisteredDetectors() async throws {
        struct Stub: ToolDetector {
            let id: ToolID
            let displayName: String
            let version: SemVer
            func detect() async throws -> DetectionResult {
                DetectionResult(toolId: id, version: version, installPath: "/usr/bin/\(id.rawValue)")
            }
        }
        let registry = DetectorRegistry()
        await registry.register(Stub(id: .node, displayName: "Node", version: SemVer(major: 20, minor: 0, patch: 0)))
        await registry.register(Stub(id: .python, displayName: "Python", version: SemVer(major: 3, minor: 12, patch: 0)))
        await registry.register(Stub(id: .git, displayName: "Git", version: SemVer(major: 2, minor: 45, patch: 0)))

        let results = await registry.scanAll()
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(Set(results.map { $0.toolId }), Set([.node, .python, .git]))
        for r in results {
            XCTAssertNotNil(r.version)
            XCTAssertNotNil(r.installPath)
        }
    }
}
