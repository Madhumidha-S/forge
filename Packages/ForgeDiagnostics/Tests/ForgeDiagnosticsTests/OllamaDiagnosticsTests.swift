import XCTest
import ForgeCore
@testable import ForgeDiagnostics

final class OllamaDiagnosticsTests: XCTestCase {

    func testOllamaMissingReturnsEmpty() async throws {
        let runner = FakeCommandRunner { _, _ in
            CommandResult(stdout: "", stderr: "ollama: command not found", exitCode: 127)
        }
        let issues = try await OllamaDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.isEmpty)
    }

    func testNoModelsProducesNoIssues() async throws {
        let runner = FakeCommandRunner { _, args in
            if args.contains("list") {
                // Header only.
                return CommandResult(stdout: "NAME                ID            SIZE      MODIFIED\n", stderr: "", exitCode: 0)
            }
            return CommandResult(stdout: "", stderr: "", exitCode: 0)
        }
        let issues = try await OllamaDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.isEmpty)
    }

    func testLargeModelTriggersCritical() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.ollamaList(models: [
            (name: "codellama:70b", sizeBytes: 38_000_000_000, modifiedRelativeSeconds: 86400)  // 38 GB
        ]))
        let issues = try await OllamaDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].title, "Ollama models")
        XCTAssertEqual(issues[0].severity, .critical)
    }

    func testMidSizeModelTriggersWarning() async throws {
        let runner = FakeCommandRunner(script: FakeCommandRunner.ollamaList(models: [
            (name: "mistral:7b", sizeBytes: 8_000_000_000, modifiedRelativeSeconds: 86400)  // 8 GB
        ]))
        let issues = try await OllamaDiagnostics().diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues[0].severity, .warning)
    }

    func testStaleModelTriggersUnusedWarning() async throws {
        let now = Date()
        // Model modified 120 days ago — qualifies as stale.
        let runner = FakeCommandRunner(script: FakeCommandRunner.ollamaList(models: [
            (name: "old-model:1", sizeBytes: 2_000_000_000, modifiedRelativeSeconds: 120 * 86400)
        ]))
        let diag = OllamaDiagnostics(now: { now })
        let issues = try await diag.diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertTrue(issues.contains { $0.title == "Ollama unused models" })
    }

    func testRecentModelDoesNotTriggerUnusedWarning() async throws {
        let now = Date()
        // Model modified 5 days ago — not stale.
        let runner = FakeCommandRunner(script: FakeCommandRunner.ollamaList(models: [
            (name: "fresh:1", sizeBytes: 2_000_000_000, modifiedRelativeSeconds: 5 * 86400)
        ]))
        let diag = OllamaDiagnostics(now: { now })
        let issues = try await diag.diagnose(context: DiagnosticsContext(commandRunner: runner))
        XCTAssertFalse(issues.contains { $0.title == "Ollama unused models" })
    }

    func testParseModifiedRelative() {
        let now = Date()
        let dayAgo = OllamaDiagnostics.parseModified("1 day ago", relativeTo: now)
        XCTAssertEqual(dayAgo.timeIntervalSince(now), -86400, accuracy: 1)

        let fiveDaysAgo = OllamaDiagnostics.parseModified("5 days ago", relativeTo: now)
        XCTAssertEqual(fiveDaysAgo.timeIntervalSince(now), -5 * 86400, accuracy: 1)

        let twoWeeksAgo = OllamaDiagnostics.parseModified("2 weeks ago", relativeTo: now)
        XCTAssertEqual(twoWeeksAgo.timeIntervalSince(now), -14 * 86400, accuracy: 1)

        let justNow = OllamaDiagnostics.parseModified("just now", relativeTo: now)
        XCTAssertEqual(justNow.timeIntervalSince(now), 0, accuracy: 1)
    }
}
