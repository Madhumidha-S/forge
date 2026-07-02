import XCTest
import ForgeCore
@testable import ForgeDiagnostics

// MARK: - Stub providers

/// Minimal `ToolDiagnostics` for tests. Returns a fixed list of issues
/// after an optional delay. Throws when `shouldThrow` is true.
private struct StubProvider: ToolDiagnostics {
    let toolID: ToolID
    let issues: [DiagnosticIssue]
    let delayMillis: UInt64?
    let shouldThrow: Bool

    init(
        toolID: ToolID,
        issues: [DiagnosticIssue] = [],
        delayMillis: UInt64? = nil,
        shouldThrow: Bool = false
    ) {
        self.toolID = toolID
        self.issues = issues
        self.delayMillis = delayMillis
        self.shouldThrow = shouldThrow
    }

    func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue] {
        if let delayMillis {
            try await Task.sleep(nanoseconds: delayMillis * 1_000_000)
        }
        if shouldThrow {
            throw NSError(
                domain: "StubProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "stub failure for \(toolID.rawValue)"]
            )
        }
        return issues
    }
}

// MARK: - Issue factories

private func issue(
    tool: ToolID,
    severity: DiagnosticSeverity = .warning,
    savingsBytes: UInt64? = nil
) -> DiagnosticIssue {
    DiagnosticIssue(
        toolID: tool,
        title: "\(tool.rawValue) issue",
        explanation: "explanation",
        severity: severity,
        estimatedSavingsBytes: savingsBytes
    )
}

// MARK: - Tests

final class DiagnosticsEngineTests: XCTestCase {

    // MARK: Empty / single / fan-out

    func testAnalyzeWithNoProvidersReturnsEmptyArray() async throws {
        let engine = DiagnosticsEngine()
        let result = try await engine.analyze()
        XCTAssertEqual(result, [])
    }

    func testAnalyzeByToolIDWithNoProviderReturnsEmptyArray() async throws {
        let engine = DiagnosticsEngine()
        let result = try await engine.analyze(toolID: .node)
        XCTAssertEqual(result, [])
    }

    func testSingleProviderIssuesAreReturned() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(
            toolID: .docker,
            issues: [issue(tool: .docker, severity: .critical, savingsBytes: 1_000)]
        ))

        let result = try await engine.analyze()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolID, .docker)
        XCTAssertEqual(result[0].severity, .critical)
    }

    func testFanOutAcrossMultipleProviders() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, issues: [issue(tool: .docker)]))
        await engine.register(StubProvider(toolID: .git,    issues: [issue(tool: .git)]))
        await engine.register(StubProvider(toolID: .node,   issues: [issue(tool: .node)]))

        let result = try await engine.analyze()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(Set(result.map(\.toolID)), Set([.docker, .git, .node]))
    }

    // MARK: Sort order

    func testResultsAreSortedBySeverityThenSavingsDesc() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, issues: [
            issue(tool: .docker, severity: .warning, savingsBytes: 5_000),
            issue(tool: .docker, severity: .info,    savingsBytes: 9_999),
            issue(tool: .docker, severity: .critical, savingsBytes: 100),
        ]))
        await engine.register(StubProvider(toolID: .git, issues: [
            issue(tool: .git, severity: .warning, savingsBytes: 2_000),
        ]))

        let result = try await engine.analyze()

        // Critical first (100), then warnings (5000, 2000), then info (9999).
        XCTAssertEqual(result.map(\.severity), [.critical, .warning, .warning, .info])
        XCTAssertEqual(result.map(\.estimatedSavingsBytes), [100, 5_000, 2_000, 9_999])
    }

    // MARK: Error containment

    func testProviderThrowBecomesWarningIssue() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, shouldThrow: true))
        await engine.register(StubProvider(toolID: .git, issues: [issue(tool: .git)]))

        let result = try await engine.analyze()
        XCTAssertEqual(result.count, 2)

        // The throwing provider produced exactly one warning issue.
        let dockerIssues = result.filter { $0.toolID == .docker }
        XCTAssertEqual(dockerIssues.count, 1)
        XCTAssertEqual(dockerIssues[0].severity, .warning)
        XCTAssertEqual(dockerIssues[0].fixAvailable, false)

        // The healthy provider's issues survived intact.
        XCTAssertTrue(result.contains { $0.toolID == .git })
    }

    // MARK: analyze(toolID:)

    func testAnalyzeByToolIDRunsOnlyThatProvider() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, issues: [issue(tool: .docker)]))
        await engine.register(StubProvider(toolID: .git,    issues: [issue(tool: .git)]))

        let result = try await engine.analyze(toolID: .git)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].toolID, .git)
    }

    func testAnalyzeByToolIDConvertsThrowIntoWarning() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, shouldThrow: true))

        let result = try await engine.analyze(toolID: .docker)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].severity, .warning)
    }

    // MARK: Cancellation

    /// `analyze()` should throw `CancellationError` when `cancel()` is
    /// called mid-flight. Uses a sleeping provider because `Task.sleep`
    /// throws `CancellationError` when its enclosing task is cancelled —
    /// which propagates cleanly through the engine's `withThrowingTaskGroup`.
    func testCancelStopsInFlightAnalysis() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, delayMillis: 60_000))

        let task = Task<[DiagnosticIssue]?, Error> {
            try await engine.analyze()
        }

        // Give the engine a moment to enter the sleeping provider.
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        await engine.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError, got success")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    /// Starting a second `analyze()` while the first is in flight should
    /// cancel the first. The first task should observe `CancellationError`.
    func testReAnalyzeCancelsPreviousInFlight() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, delayMillis: 60_000))

        let first = Task<[DiagnosticIssue]?, Error> { try await engine.analyze() }

        // Wait until the first task is definitely inside the provider.
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Starting a second analyze should cancel the first.
        let second = Task<[DiagnosticIssue]?, Error> { try await engine.analyze() }
        try await Task.sleep(nanoseconds: 30_000_000) // 30ms

        do {
            _ = try await first.value
            XCTFail("Expected first task to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError on first, got \(error)")
        }

        // The second task is still sleeping (no fast provider registered).
        // Cancel and verify.
        await engine.cancel()
        do {
            _ = try await second.value
            XCTFail("Expected second task to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError on second, got \(error)")
        }
    }

    /// After a cancelled analysis, a fresh `analyze()` with a fast provider
    /// should succeed normally — the engine is reusable.
    func testEngineIsReusableAfterCancellation() async throws {
        let engine = DiagnosticsEngine()
        await engine.register(StubProvider(toolID: .docker, delayMillis: 60_000))

        let first = Task<[DiagnosticIssue]?, Error> { try await engine.analyze() }
        try await Task.sleep(nanoseconds: 50_000_000)
        await engine.cancel()
        _ = try? await first.value // drain the cancelled task

        // Replace the slow provider with a fast one and re-run.
        await engine.register(StubProvider(
            toolID: .docker,
            issues: [issue(tool: .docker, severity: .critical)]
        ))
        let result = try await engine.analyze()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].severity, .critical)
    }
}
