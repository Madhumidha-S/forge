import XCTest
@testable import ForgeDetectors
import ForgeCore

final class NodeDetectorTests: XCTestCase {
    /// Fake runner that scripts responses per (executable basename, arguments).
    final class FakeCommandRunner: CommandRunner, @unchecked Sendable {
        struct Call {
            let executable: URL
            let arguments: [String]
        }
        private(set) var calls: [Call] = []
        let script: (URL, [String]) -> CommandResult

        init(script: @escaping (URL, [String]) -> CommandResult) {
            self.script = script
        }

        func run(executable: URL, arguments: [String]) throws -> CommandResult {
            calls.append(Call(executable: executable, arguments: arguments))
            return script(executable, arguments)
        }
    }

    func testPathResolvedBinaryReturnsVersion() async throws {
        let runner = FakeCommandRunner { exe, args in
            if exe.lastPathComponent == "which" && args == ["node"] {
                return CommandResult(stdout: "/usr/local/bin/node\n", exitCode: 0)
            }
            if exe.lastPathComponent == "node" && args == ["--version"] {
                return CommandResult(stdout: "v20.10.0\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = NodeDetector(
            homeDirectory: nil,
            commandRunner: runner
        )
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .node)
        XCTAssertEqual(result.version, SemVer(major: 20, minor: 10, patch: 0))
        XCTAssertEqual(result.installPath, "/usr/local/bin/node")
        XCTAssertEqual(result.healthChecks.first?.detail, "PATH")
        XCTAssertEqual(result.healthChecks.first?.passed, true)
        // ensure PATH path was taken (not nvm fallback)
        XCTAssertEqual(runner.calls.count, 2)
        XCTAssertEqual(runner.calls.first?.executable.lastPathComponent, "which")
        XCTAssertEqual(runner.calls.last?.arguments, ["--version"])
    }

    func testNvmOnlyBinaryReturnsVersion() async throws {
        // Simulate a temp "nvm" directory tree.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("forge-nvm-test-\(UUID().uuidString)", isDirectory: true)
        let versionDir = tmp.appendingPathComponent(".nvm/versions/node/v18.19.0/bin")
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        let nodeBinary = versionDir.appendingPathComponent("node")
        FileManager.default.createFile(atPath: nodeBinary.path, contents: nil, attributes: nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: nodeBinary.path)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let runner = FakeCommandRunner { exe, args in
            if exe.lastPathComponent == "which" {
                return CommandResult(exitCode: 1)  // PATH miss
            }
            if exe.lastPathComponent == "node" && args == ["--version"] {
                return CommandResult(stdout: "v18.19.0\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = NodeDetector(
            homeDirectory: tmp,
            commandRunner: runner
        )
        let result = try await detector.detect()
        XCTAssertEqual(result.version, SemVer(major: 18, minor: 19, patch: 0))
        XCTAssertTrue(result.installPath?.contains("v18.19.0/bin/node") == true)
        XCTAssertEqual(result.healthChecks.first?.detail, "nvm")
    }

    func testMissingBinaryReturnsNotFound() async throws {
        let runner = FakeCommandRunner { _, _ in
            CommandResult(stderr: "not found", exitCode: 1)
        }
        let detector = NodeDetector(
            homeDirectory: nil,
            commandRunner: runner
        )
        do {
            _ = try await detector.detect()
            XCTFail("Expected DetectionError.notFound")
        } catch let error as DetectionError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected DetectionError.notFound, got \(error)")
        }
    }
}
