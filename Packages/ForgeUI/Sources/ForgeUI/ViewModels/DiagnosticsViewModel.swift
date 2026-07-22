import Foundation
import SwiftUI
import ForgeCore
import ForgeDiagnostics

/// View model for the Diagnostics screen. Runs `DiagnosticsEngine.analyze()`
/// and groups the resulting issues by severity so the View can render
/// three sections (Critical / Warnings / Information) without re-sorting.
///
/// Phase 4G — first ViewModel that depends on both `AppEnvironment`
/// (for the engine) and the real `DiagnosticsIssue` value type.
@MainActor
public final class DiagnosticsViewModel: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalyzedAt: Date?
    @Published public private(set) var critical: [DiagnosticIssue] = []
    @Published public private(set) var warnings: [DiagnosticIssue] = []
    @Published public private(set) var info: [DiagnosticIssue] = []
    @Published public private(set) var totalReclaimableBytes: UInt64 = 0

    private let diagnosticsEngine: any DiagnosticsEngineProtocol
    private let onEvent: ((String) -> Void)?

    public init(
        diagnosticsEngine: any DiagnosticsEngineProtocol,
        onEvent: ((String) -> Void)? = nil
    ) {
        self.diagnosticsEngine = diagnosticsEngine
        self.onEvent = onEvent
    }

    /// Convenience initializer for SwiftUI previews.
    public static func preview() -> DiagnosticsViewModel {
        DiagnosticsViewModel(diagnosticsEngine: PreviewStubDiagnosticsEngine())
    }

    /// Runs the diagnostics engine and refreshes the severity-grouped arrays.
    /// Safe to call repeatedly — the engine handles re-entrancy.
    public func analyze() async {
        // Yield once before mutating @Published state so the writes
        // land outside any in-flight SwiftUI view-update pass and
        // don't trip the "Publishing changes from within view updates"
        // runtime check.
        await Task.yield()
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let result = try await diagnosticsEngine.analyze()
            apply(result)
            lastAnalyzedAt = Date()
            onEvent?("Diagnostics refreshed: \(critical.count) critical, \(warnings.count) warnings, \(info.count) info")
        } catch {
            apply([])
            lastAnalyzedAt = Date()
            onEvent?("Diagnostics refresh failed: \(error.localizedDescription)")
        }
    }

    private func apply(_ issues: [DiagnosticIssue]) {
        // Sort each bucket by estimated savings desc so the most impactful
        // issues surface first within each severity group.
        let sorted = issues.sorted { lhs, rhs in
            if lhs.severity != rhs.severity {
                return lhs.severity.order < rhs.severity.order
            }
            return (lhs.estimatedSavingsBytes ?? 0) > (rhs.estimatedSavingsBytes ?? 0)
        }
        critical = sorted.filter { $0.severity == .critical }
        warnings = sorted.filter { $0.severity == .warning }
        info = sorted.filter { $0.severity == .info }
        totalReclaimableBytes = issues.reduce(UInt64(0)) { $0 + ($1.estimatedSavingsBytes ?? 0) }
    }
}

// MARK: - Preview stub

private final class PreviewStubDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] {
        [
            DiagnosticIssue(
                toolID: .docker,
                title: "Docker stopped containers",
                explanation: "There are 3 stopped containers holding disk space.",
                severity: .warning,
                estimatedSavingsBytes: 2_100_000_000
            ),
            DiagnosticIssue(
                toolID: .xcode,
                title: "Xcode DerivedData",
                explanation: "Build artifacts have accumulated.",
                severity: .critical,
                estimatedSavingsBytes: 18_400_000_000
            ),
            DiagnosticIssue(
                toolID: .ollama,
                title: "Unused Ollama models",
                explanation: "Models older than 90 days.",
                severity: .info,
                estimatedSavingsBytes: 6_800_000_000
            )
        ]
    }
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}
