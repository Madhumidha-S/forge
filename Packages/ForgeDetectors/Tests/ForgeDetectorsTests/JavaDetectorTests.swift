import XCTest
@testable import ForgeDetectors
import ForgeCore

final class JavaDetectorTests: XCTestCase {
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
            if exe.path == "/usr/libexec/java_home" && args.isEmpty {
                return CommandResult(stdout: "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home\n", exitCode: 0)
            }
            if exe.path == "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java" && args == ["-version"] {
                return CommandResult(stderr: "openjdk version \"17.0.10\" 2024-01-16\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = JavaDetector(commandRunner: runner)
        let result = try await detector.detect()
        XCTAssertEqual(result.toolId, .java)
        XCTAssertEqual(result.version, SemVer(major: 17, minor: 0, patch: 10))
        XCTAssertEqual(result.installPath, "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home")
        XCTAssertEqual(result.healthChecks.first?.name, "binary-source")
        XCTAssertEqual(result.healthChecks.first?.detail, "java_home")
        XCTAssertEqual(result.healthChecks.first?.passed, true)
        XCTAssertEqual(runner.calls.count, 3)
    }

    func testNotInstalledThrowsNotFound() async throws {
        let runner = FakeCommandRunner { _, _ in
            CommandResult(stderr: "not found\n", exitCode: 1)
        }
        let detector = JavaDetector(commandRunner: runner)
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
            if exe.path == "/usr/libexec/java_home" && args.isEmpty {
                return CommandResult(stdout: "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home\n", exitCode: 0)
            }
            if exe.path == "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/bin/java" && args == ["-version"] {
                return CommandResult(stderr: "garbage output with no quoted version\n", exitCode: 0)
            }
            return CommandResult(exitCode: 1)
        }
        let detector = JavaDetector(commandRunner: runner)
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
