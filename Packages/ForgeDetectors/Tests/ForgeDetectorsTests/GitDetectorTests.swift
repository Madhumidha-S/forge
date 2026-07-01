import XCTest
@testable import ForgeDetectors
import ForgeCore

final class GitDetectorTests: XCTestCase {
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

    func testInstalledReturnsVersionAndPath() async throws {
        let runner = FakeCommandRunner { exe, args in
            if exe.lastPathComponent == "zsh" && args == ["-ilc", "command -v git"] {
                return CommandResult(stdout: "/usr/bin/git\n", exitCode: 0)
            }
            if exe.lastPathComponent == "git" && args == ["--version"] {
                return CommandResult(stdout: "git version 2.45.0\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = GitDetector(commandRunner: runner)
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .git)
        XCTAssertEqual(result.version, SemVer(major: 2, minor: 45, patch: 0))
        XCTAssertEqual(result.installPath, "/usr/bin/git")
        XCTAssertEqual(result.healthChecks.first?.name, "binary-source")
        XCTAssertEqual(result.healthChecks.first?.detail, "PATH")
        XCTAssertEqual(result.healthChecks.first?.passed, true)
        XCTAssertEqual(runner.calls.count, 2)
    }

    func testNotInstalledThrowsNotFound() async throws {
        let runner = FakeCommandRunner { _, _ in
            CommandResult(stderr: "not found\n", exitCode: 1)
        }
        let detector = GitDetector(commandRunner: runner)
        do {
            _ = try await detector.detect()
            XCTFail("Expected DetectionError.notFound")
        } catch let error as DetectionError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Expected DetectionError.notFound, got \(error)")
        }
    }

    func testMalformedVersionThrowsMalformedOutput() async throws {
        let runner = FakeCommandRunner { exe, args in
            if exe.lastPathComponent == "zsh" && args == ["-ilc", "command -v git"] {
                return CommandResult(stdout: "/usr/bin/git\n", exitCode: 0)
            }
            if exe.lastPathComponent == "git" && args == ["--version"] {
                return CommandResult(stdout: "garbage\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = GitDetector(commandRunner: runner)
        do {
            _ = try await detector.detect()
            XCTFail("Expected DetectionError.malformedOutput")
        } catch let error as DetectionError {
            if case .malformedOutput = error { return }
            XCTFail("Expected DetectionError.malformedOutput, got \(error)")
        } catch {
            XCTFail("Expected DetectionError.malformedOutput, got \(error)")
        }
    }
}
