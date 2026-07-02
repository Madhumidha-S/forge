import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class DockerDiagnosticsTests: XCTestCase {

    func testDockerMissingReturnsEmpty() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.dockerMissing)
        let context = DiagnosticsContext(commandRunner: runner)
        let issues = try await DockerDiagnostics().diagnose(context: context)
        XCTAssertTrue(issues.isEmpty, "Missing docker binary should produce zero issues")
    }

    func testImagesTriggerAt10GB() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.dockerSystemDf(
            imagesBytes: 12_000_000_000,  // 12 GB → critical
            volumesBytes: 0,
            buildCacheBytes: 0
        ))
        let issues = try await DockerDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        let imageIssues = issues.filter { $0.title == "Docker images" }
        XCTAssertEqual(imageIssues.count, 1)
        XCTAssertEqual(imageIssues[0].severity, .critical)
    }

    func testImagesTriggerAt1GB() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.dockerSystemDf(
            imagesBytes: 1_500_000_000,  // 1.5 GB → warning
            volumesBytes: 0,
            buildCacheBytes: 0
        ))
        let issues = try await DockerDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        let imageIssues = issues.filter { $0.title == "Docker images" }
        XCTAssertEqual(imageIssues.count, 1)
        XCTAssertEqual(imageIssues[0].severity, .warning)
    }

    func testImagesBelow1GBProduceNoIssue() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.dockerSystemDf(
            imagesBytes: 500_000_000,  // 500 MB → below threshold
            volumesBytes: 0,
            buildCacheBytes: 0
        ))
        let issues = try await DockerDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.isEmpty)
    }

    func testStoppedContainersTriggersWarning() async throws {
        // Inline closure that handles all three Docker calls (system df,
        // ps exited, ps created) without nesting dockerSystemDf's factory.
        let runner = FakeCommandRunner { _, args in
            if args.contains("system") {
                // Hardcoded system df output — all zeros so no size issues.
                return CommandResult(
                    stdout: "Images\t0B\t0B\nContainers\t0B\t0B\nLocal Volumes\t0B\t0B\nBuild Cache\t0B\t0B\n",
                    stderr: "",
                    exitCode: 0
                )
            }
            if args.contains("ps") && args.contains("exited") {
                return CommandResult(stdout: "abc123\ndef456\nghi789\n", stderr: "", exitCode: 0)
            }
            if args.contains("ps") && args.contains("created") {
                return CommandResult(stdout: "", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
        let issues = try await DockerDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Docker stopped containers")
        XCTAssertEqual(issues[0].severity, .warning)
        XCTAssertTrue(issues[0].explanation.contains("3"))
    }

    func testParseSizeHandlesCommonUnits() {
        XCTAssertEqual(DockerDiagnostics.parseSize("0B"), 0)
        XCTAssertEqual(DockerDiagnostics.parseSize("234MB"), 234_000_000)
        XCTAssertEqual(DockerDiagnostics.parseSize("12.3GB"), UInt64(12.3 * 1_000_000_000))
        XCTAssertEqual(DockerDiagnostics.parseSize("1.5TB"), UInt64(1.5 * 1_000_000_000_000))
        XCTAssertEqual(DockerDiagnostics.parseSize(""), 0)
        XCTAssertEqual(DockerDiagnostics.parseSize("garbage"), 0)
    }
}
