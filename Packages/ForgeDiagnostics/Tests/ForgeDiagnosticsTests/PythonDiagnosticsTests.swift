import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class PythonDiagnosticsTests: XCTestCase {

    func testNoPython3OnPathTriggersWarning() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.whichPython3(paths: []))
        let issues = try await PythonDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Python 3 not on PATH")
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testSinglePythonProducesNoIssues() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.whichPython3(paths: [
            "/usr/local/bin/python3"
        ]))
        let issues = try await PythonDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.isEmpty)
    }

    func testTwoPythonsTriggersInfo() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.whichPython3(paths: [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3"
        ]))
        let issues = try await PythonDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Two Python installations")
        XCTAssertEqual(issues[0].severity, .info)
    }

    func testThreeOrMorePythonsTriggersInfo() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.whichPython3(paths: [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3"
        ]))
        let issues = try await PythonDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Multiple Python installations")
        XCTAssertEqual(issues[0].severity, .info)
    }

    func testBrokenPythonTriggersWarning() async throws {
        // The `which -a python3` succeeds with one candidate, but the
        // `python3 -c "..."` exec check fails — a broken symlink.
        let runner = FakeCommandRunner { exe, args in
            if args == ["-a", "python3"] {
                return CommandResult(stdout: "/usr/local/bin/python3\n", stderr: "", exitCode: 0)
            }
            if args.contains("-c") {
                return CommandResult(stdout: "", stderr: "dyld: broken symlink", exitCode: 1)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 1)
        }
        let issues = try await PythonDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Broken python3 on PATH")
        XCTAssertEqual(issues[0].severity, .warning)
    }
}
