import XCTest
@testable import ForgeDetectors
import ForgeCore

final class HomebrewDetectorTests: XCTestCase {
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

    final class FakeFileManager: FileManager {
        var executablePaths: Set<String> = []

        override func isExecutableFile(atPath path: String) -> Bool {
            return executablePaths.contains(path)
        }
    }

    func testInstalledReturnsVersionAndPath() async throws {
        let fileManager = FakeFileManager()
        fileManager.executablePaths = ["/opt/homebrew/bin/brew"]

        let runner = FakeCommandRunner { exe, args in
            if exe.path == "/opt/homebrew/bin/brew" && args == ["--version"] {
                return CommandResult(stdout: "Homebrew 4.3.5\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }

        let detector = HomebrewDetector(fileManager: fileManager, commandRunner: runner)
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .homebrew)
        XCTAssertEqual(result.version, SemVer(major: 4, minor: 3, patch: 5))
        XCTAssertEqual(result.installPath, "/opt/homebrew/bin/brew")
        XCTAssertEqual(result.healthChecks.first?.name, "binary-source")
        XCTAssertEqual(result.healthChecks.first?.detail, "apple-silicon")
        XCTAssertEqual(result.healthChecks.first?.passed, true)
        XCTAssertEqual(runner.calls.count, 1)
    }

    func testNotInstalledThrowsNotFound() async throws {
        let fileManager = FakeFileManager()
        fileManager.executablePaths = []

        let runner = FakeCommandRunner { _, _ in
            CommandResult(exitCode: 1)
        }

        let detector = HomebrewDetector(fileManager: fileManager, commandRunner: runner)
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
        let fileManager = FakeFileManager()
        fileManager.executablePaths = ["/usr/local/bin/brew"]

        let runner = FakeCommandRunner { exe, args in
            if exe.path == "/usr/local/bin/brew" && args == ["--version"] {
                return CommandResult(stdout: "???\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }

        let detector = HomebrewDetector(fileManager: fileManager, commandRunner: runner)
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
