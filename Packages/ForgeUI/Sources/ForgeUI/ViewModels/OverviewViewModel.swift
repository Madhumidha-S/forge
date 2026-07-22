import Foundation
import SwiftUI
import ForgeCore
import ForgeDiagnostics

/// View model for the Overview screen. Coordinates with the diagnostics
/// engine: on appear, runs `diagnosticsEngine.analyze()`, derives the
/// health score from the issue counts, and formats the cleanup estimate.
///
/// Phase 4F.2 — first end-to-end ViewModel that touches the diagnostics
/// engine from the UI layer. The Overview screen is the landing tab on
/// cold launch, so this also validates the AppEnvironment.live(...) wiring
/// from Phase 4E end-to-end.
@MainActor
public final class OverviewViewModel: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var issues: [DiagnosticIssue] = []
    @Published public private(set) var lastAnalyzedAt: Date?
    /// True once at least one analyze() call has completed successfully.
    /// UI uses this to distinguish "haven't scanned yet" from "scan found nothing".
    @Published public private(set) var hasScanned = false

    private let diagnosticsEngine: any DiagnosticsEngineProtocol
    private let onEvent: ((String) -> Void)?
    private let toolsCountProvider: () -> Int
    private let onAnalyzeFailure: (() -> Void)?

    public init(
        diagnosticsEngine: any DiagnosticsEngineProtocol,
        onEvent: ((String) -> Void)? = nil,
        toolsCountProvider: @escaping () -> Int = { 0 },
        onAnalyzeFailure: (() -> Void)? = nil
    ) {
        self.diagnosticsEngine = diagnosticsEngine
        self.onEvent = onEvent
        self.toolsCountProvider = toolsCountProvider
        self.onAnalyzeFailure = onAnalyzeFailure
    }

    /// Convenience initializer for SwiftUI previews that don't have an
    /// AppEnvironment wired up.
    public static func preview() -> OverviewViewModel {
        OverviewViewModel(diagnosticsEngine: PreviewStubDiagnosticsEngine())
    }

    /// Runs the diagnostics engine and refreshes `issues` + `lastAnalyzedAt`.
    /// Safe to call repeatedly — the engine handles re-entrancy.
    public func analyze() async {
        // Yield once before mutating @Published state. If this method is
        // invoked from a `.task` modifier or a button's `Task { ... }`
        // while SwiftUI is still in the middle of a view-update pass,
        // mutating `isAnalyzing` synchronously here would trip the
        // "Publishing changes from within view updates" runtime check.
        // The yield pushes our state writes past the current update.
        await Task.yield()
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await diagnosticsEngine.analyze()
            issues = result
            lastAnalyzedAt = Date()
            hasScanned = true
            onEvent?("Diagnostics complete: \(result.count) issues")
        } catch {
            issues = []
            lastAnalyzedAt = Date()
            onEvent?("Diagnostics scan failed: \(error.localizedDescription)")
            onAnalyzeFailure?()
        }
    }

    // MARK: - Derived metrics for the Overview screen

    /// Health score from 0 (all critical) to 100 (no issues). Uses the
    /// severity-weighted count to derive the score. The formula:
    ///   critical = 10 points off each
    ///   warning  = 3 points off each
    ///   info     = 0.5 points off each (rounded down)
    /// Floors at 0. This is a placeholder heuristic — Phase 4G may
    /// refine it based on telemetry (e.g. weight by storage impact).
    /// Health score 0–100, derived from real issue severity weights.
    /// Returns nil until the first scan completes — UI must show
    /// "Not yet analyzed" rather than a default of 100.
    public var healthScore: Int? {
        guard hasScanned else { return nil }
        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let penalty = criticalCount * 10 + warningCount * 3 + infoCount / 2
        return max(0, 100 - penalty)
    }

    /// Count of detected tools that are healthy. Returns the count of
    /// detected tools minus the count of warning/critical issues
    /// (each issue tied to a single tool), floored at 0. Returns nil
    /// until the first scan completes.
    public var healthyCount: Int? {
        guard hasScanned else { return nil }
        let flagged = issues.filter { $0.severity == .warning || $0.severity == .critical }.count
        return max(toolsCountProvider() - flagged, 0)
    }

    /// Total detected tools — comes from the tools view model passed in via
    /// the toolsCountProvider closure, not from a hardcoded constant.
    public var detectedToolsCount: Int {
        toolsCountProvider()
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public var criticalCount: Int {
        issues.filter { $0.severity == .critical }.count
    }

    /// Total reclaimable storage across all issues. Summing the per-issue
    /// `estimatedSavingsBytes` is the right primitive — the diagnostics
    /// providers already populate that field conservatively.
    public var potentialCleanupBytes: UInt64 {
        issues.reduce(UInt64(0)) { $0 + ($1.estimatedSavingsBytes ?? 0) }
    }

    /// Top 3 issues by severity (critical first), then by savings desc.
    /// Used by the "Recently Detected" section of the Overview.
    public var recentIssues: [DiagnosticIssue] {
        Array(issues.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.order < rhs.severity.order
            }
            return (lhs.estimatedSavingsBytes ?? 0) > (rhs.estimatedSavingsBytes ?? 0)
        }.prefix(3))
    }
}

// MARK: - Preview stub

/// No-op diagnostics engine for SwiftUI previews. Returns an empty array
/// from `analyze()` so the Overview screen renders its empty / loading
/// state during design-time iteration.
private final class PreviewStubDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] { [] }
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}
