import Foundation
import ForgeCore

/// Actor-based diagnostics engine.
///
/// The engine owns a dictionary of registered `ToolDiagnostics` providers,
/// one per `ToolID`. `analyze()` fans out across all providers concurrently
/// using `withTaskGroup`; per-provider errors are caught and converted into
/// a single warning `DiagnosticIssue` so one broken provider cannot abort
/// the whole analysis.
///
/// Concurrency notes
/// -----------------
/// - `analyze()` and `analyze(toolID:)` are serialized through the actor.
///   Calling `analyze()` while another analysis is in flight cancels the
///   first via `Task.cancel()` so the UI always gets the freshest result.
/// - `cancel()` can be called from any isolation; it cancels the in-flight
///   task (if any). The next `analyze()` call starts fresh.
/// - The returned issues are sorted by `(severity, savingsBytes desc)` so
///   the UI surfaces critical issues first.
public actor DiagnosticsEngine: DiagnosticsEngineProtocol {
    private var providers: [ToolID: any ToolDiagnostics] = [:]
    private var inFlight: Task<[DiagnosticIssue], Error>?

    public init() {}

    /// Registers a provider, replacing any existing provider with the same
    /// `toolID`. Calling `register` while an analysis is running does not
    /// affect that analysis — it uses the providers snapshot taken at the
    /// start of `analyze()`.
    public func register(_ provider: any ToolDiagnostics) {
        providers[provider.toolID] = provider
    }

    /// Runs every registered provider concurrently and returns the merged
    /// list of issues. Results are sorted by `(severity, savingsBytes desc)`.
    ///
    /// If an `analyze()` is already running, it is cancelled before the
    /// new one starts. `inFlight` is simply overwritten by the next call —
    /// clearing it after completion would race with concurrent calls and
    /// is unnecessary because `cancel()` on a completed task is a no-op.
    public func analyze() async throws -> [DiagnosticIssue] {
        inFlight?.cancel()

        let snapshot = Array(providers.values)
        let context = DiagnosticsContext()
        let task = Task<[DiagnosticIssue], Error> { [snapshot, context] in
            try await Self.runAnalysis(snapshot, context: context)
        }
        inFlight = task

        return try await task.value
    }

    /// Runs the provider for the given tool, if one is registered.
    /// Returns an empty array when no provider is registered for the tool.
    /// Per-provider errors are caught and surfaced as a single warning
    /// `DiagnosticIssue`.
    public func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] {
        guard let provider = providers[toolID] else { return [] }
        let context = DiagnosticsContext()
        return try await Self.runProvider(provider, context: context)
    }

    /// Cancels any in-flight analysis. Safe to call from any isolation.
    public func cancel() {
        inFlight?.cancel()
        inFlight = nil
    }

    // MARK: - Static helpers (run outside actor isolation)

    /// Runs every provider in the snapshot concurrently. Per-provider
    /// errors are caught and converted into a warning `DiagnosticIssue`
    /// so one broken provider doesn't poison the whole analysis.
    ///
    /// This function is `throws` so that `CancellationError` from a child
    /// task can propagate back to `analyze()`. Non-cancellation errors
    /// are converted to warning issues inside `runProvider` and do not
    /// escape the task group.
    private static func runAnalysis(
        _ snapshot: [any ToolDiagnostics],
        context: DiagnosticsContext
    ) async throws -> [DiagnosticIssue] {
        guard !snapshot.isEmpty else { return [] }

        var issues: [DiagnosticIssue] = []
        issues.reserveCapacity(snapshot.count)

        try await withThrowingTaskGroup(of: [DiagnosticIssue].self) { group in
            for provider in snapshot {
                group.addTask {
                    try await runProvider(provider, context: context)
                }
            }
            for try await providerIssues in group {
                issues.append(contentsOf: providerIssues)
            }
        }

        return issues.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.order < rhs.severity.order
            }
            return (lhs.estimatedSavingsBytes ?? 0) > (rhs.estimatedSavingsBytes ?? 0)
        }
    }

    /// Runs a single provider.
    /// - On success, returns the provider's issues.
    /// - On `CancellationError`, rethrows so the enclosing task group can
    ///   propagate cancellation to the caller.
    /// - On any other error, returns a single warning `DiagnosticIssue`.
    private static func runProvider(
        _ provider: any ToolDiagnostics,
        context: DiagnosticsContext
    ) async throws -> [DiagnosticIssue] {
        do {
            return try await provider.diagnose(context: context)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return [DiagnosticIssue(
                toolID: provider.toolID,
                title: "Diagnostic failed",
                explanation: "Failed to run \(provider.toolID.rawValue) diagnostic: \(error)",
                severity: .warning,
                fixAvailable: false,
                remediationText: "Re-run the analysis. If it keeps failing, the diagnostic for \(provider.toolID.rawValue) is broken."
            )]
        }
    }
}
