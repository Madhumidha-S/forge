import XCTest
@testable import ForgeDetectors
import ForgeCore

final class OllamaDetectorTests: XCTestCase {
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
            if exe.lastPathComponent == "which" && args == ["ollama"] {
                return CommandResult(stdout: "/usr/local/bin/ollama\n", exitCode: 0)
            }
            if exe.path == "/usr/local/bin/ollama" && args == ["--version"] {
                return CommandResult(stdout: "ollama version 0.3.12\n", exitCode: 0)
            }
            if exe.path == "/usr/bin/pgrep" && args == ["-x", "ollama"] {
                return CommandResult(stdout: "1234\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = OllamaDetector(commandRunner: runner)
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .ollama)
        XCTAssertEqual(result.version, SemVer(major: 0, minor: 3, patch: 12))
        XCTAssertEqual(result.installPath, "/usr/local/bin/ollama")
        XCTAssertEqual(result.runningStatus, .running)
        XCTAssertEqual(result.healthChecks[0].name, "binary-source")
        XCTAssertEqual(result.healthChecks[0].detail, "PATH")
        XCTAssertEqual(result.healthChecks[0].passed, true)
        XCTAssertEqual(result.healthChecks[1].name, "process-running")
        XCTAssertEqual(result.healthChecks[1].passed, true)
        XCTAssertEqual(runner.calls.count, 3)
    }

    func testInstalledWithIsFormatParsesVersion() async throws {
        let runner = FakeCommandRunner { exe, args in
            if exe.lastPathComponent == "which" && args == ["ollama"] {
                return CommandResult(stdout: "/opt/homebrew/bin/ollama\n", exitCode: 0)
            }
            if exe.path == "/opt/homebrew/bin/ollama" && args == ["--version"] {
                return CommandResult(stdout: "ollama version is 0.12.6\n", exitCode: 0)
            }
            if exe.path == "/usr/bin/pgrep" && args == ["-x", "ollama"] {
                return CommandResult(stdout: "1234\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = OllamaDetector(commandRunner: runner)
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .ollama)
        XCTAssertEqual(result.version, SemVer(major: 0, minor: 12, patch: 6))
        XCTAssertEqual(result.installPath, "/opt/homebrew/bin/ollama")
        XCTAssertEqual(result.runningStatus, .running)
        XCTAssertEqual(result.healthChecks[0].name, "binary-source")
        XCTAssertEqual(result.healthChecks[0].detail, "PATH")
        XCTAssertEqual(result.healthChecks[0].passed, true)
        XCTAssertEqual(result.healthChecks[1].name, "process-running")
        XCTAssertEqual(result.healthChecks[1].passed, true)
        XCTAssertEqual(runner.calls.count, 3)
    }

    func testNotInstalledThrowsNotFound() async throws {
        let runner = FakeCommandRunner { _, _ in
            CommandResult(stderr: "not found\n", exitCode: 1)
        }
        let detector = OllamaDetector(commandRunner: runner)
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
            if exe.lastPathComponent == "which" && args == ["ollama"] {
                return CommandResult(stdout: "/usr/local/bin/ollama\n", exitCode: 0)
            }
            if exe.path == "/usr/local/bin/ollama" && args == ["--version"] {
                return CommandResult(stdout: "??? garbage ???\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = OllamaDetector(commandRunner: runner)
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
