import Foundation
import SwiftUI
import SwiftData
import ForgeCore
import ForgeDiagnostics

/// View model for the Cleanup screen. Aggregates the available cleanup
/// actions from `CleanupServiceRegistryProtocol` and the diagnostic issues
/// from `DiagnosticsEngineProtocol` into a single list of cleanup
/// opportunities the screen can render.
///
/// Phase 4I — first ViewModel that crosses the diagnostics-engine
/// boundary and the cleanup-registry boundary, giving the Cleanup screen
/// a unified "what can I reclaim and how" view.
///
/// The View model never calls `dryRun()` for every action on appear —
/// dry-runs can be expensive (they walk the filesystem). It exposes
/// `preview(_:)` and `previewAll()` for the View to call on demand.
@MainActor
public final class CleanupViewModel: ObservableObject {
    @Published public private(set) var opportunities: [CleanupOpportunity] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var preview: CleanupPreview?
    @Published public private(set) var lastError: String?

    private let environment: AppEnvironment
    private let onEvent: ((String) -> Void)?

    public init(
        environment: AppEnvironment,
        onEvent: ((String) -> Void)? = nil
    ) {
        self.environment = environment
        self.onEvent = onEvent
    }

    /// Convenience initializer for SwiftUI previews that don't have an
    /// `AppEnvironment` wired up. Uses a preview stub environment with
    /// Xcode + Homebrew cleanup actions and a few diagnostic issues.
    public static func preview() -> CleanupViewModel {
        CleanupViewModel(environment: makePreviewAppEnvironment())
    }

    /// Refreshes the opportunities list. Reads the available cleanup
    /// actions from the cleanup registry and pairs them with diagnostic
    /// issues (where possible) to estimate the reclaimable bytes per
    /// action. Issues without a matching action still appear, with a
    /// `null` action — the user can still preview them in a future phase.
    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let actions = await environment.cleanupServiceRegistry.availableActions()
        let issues = (try? await environment.diagnosticsEngine.analyze()) ?? []
        opportunities = Self.pair(actions: actions, issues: issues)
        onEvent?("Cleanup scan complete: \(opportunities.count) recommendations")
    }

    /// Runs the dry-run for a specific cleanup action and stores the
    /// resulting `DryRunReport` in `preview` so the View can present it.
    public func preview(_ opportunity: CleanupOpportunity) async {
        guard let action = opportunity.action else {
            preview = nil
            return
        }
        do {
            preview = CleanupPreview(opportunity: opportunity, report: try await action.dryRun())
            lastError = nil
        } catch {
            preview = nil
            lastError = error.localizedDescription
        }
    }

    /// Runs the dry-run for every opportunity that has an action.
    /// Aggregates per-opportunity bytes into a single preview report
    /// so the View can show a "Preview All" sheet.
    public func previewAll() async {
        let actions = opportunities.compactMap(\.action)
        guard !actions.isEmpty else {
            preview = nil
            return
        }
        var combinedPaths: [URL] = []
        var combinedBytes: Int64 = 0
        var firstTarget: String?
        var lastScanned: Date?
        for action in actions {
            do {
                let report = try await action.dryRun()
                combinedPaths.append(contentsOf: report.candidatePaths)
                combinedBytes += report.totalReclaimableBytes
                if firstTarget == nil { firstTarget = report.target }
                lastScanned = report.scannedAt
            } catch {
                lastError = error.localizedDescription
            }
        }
        preview = CleanupPreview(
            opportunity: nil,
            report: DryRunReport(
                target: actions.count == 1 ? firstTarget ?? "Combined" : "Combined (\(actions.count) actions)",
                candidatePaths: combinedPaths,
                totalReclaimableBytes: combinedBytes,
                scannedAt: lastScanned ?? Date()
            )
        )
    }

    /// Clears the preview sheet.
    public func dismissPreview() {
        preview = nil
    }

    // MARK: - Pairing

    /// Pairs cleanup actions with diagnostic issues by ID. Issues without
    /// a matching action still appear in the opportunities list so the
    /// user can see what diagnostics flagged even without a cleanup action.
    static func pair(
        actions: [any CleanupActionProtocol],
        issues: [DiagnosticIssue]
    ) -> [CleanupOpportunity] {
        // Group diagnostic issues by tool so we can sum their savings per
        // tool, then map to the cleanup action's display target.
        let savingsByTool: [ToolID: UInt64] = issues.reduce(into: [:]) { acc, issue in
            acc[issue.toolID, default: 0] += issue.estimatedSavingsBytes ?? 0
        }

        // Best-effort tool ID resolution from the action's displayName or id.
        // Not all actions map cleanly to a ToolID — we keep them in the list
        // with zero estimated savings in that case.
        return actions.map { action in
            let toolID = inferToolID(from: action)
            let savings = savingsByTool[toolID] ?? 0
            return CleanupOpportunity(action: action, toolID: toolID, estimatedSavingsBytes: savings)
        }
        .sorted { $0.estimatedSavingsBytes > $1.estimatedSavingsBytes }
    }

    /// Best-effort mapping from a `CleanupActionProtocol` to a `ToolID`.
    /// Used only to attach the diagnostics-engine's estimated savings to
    /// the right row in the cleanup table. Unknown actions just show 0.
    private static func inferToolID(from action: any CleanupActionProtocol) -> ToolID {
        let haystack = "\(action.id) \(action.displayName)".lowercased()
        if haystack.contains("xcode") { return .xcode }
        if haystack.contains("flutter") { return .flutter }
        if haystack.contains("android") { return .androidStudio }
        if haystack.contains("docker") { return .docker }
        if haystack.contains("ollama") { return .ollama }
        if haystack.contains("brew") || haystack.contains("homebrew") { return .homebrew }
        if haystack.contains("git") { return .git }
        if haystack.contains("node") { return .node }
        if haystack.contains("python") { return .python }
        if haystack.contains("java") { return .java }
        return .node // fallback — unknown action
    }
}

// MARK: - Value types

/// One row in the Cleanup table — pairs an available cleanup action
/// with the diagnostic-engine's estimate of how much it can reclaim.
public struct CleanupOpportunity: Identifiable, Hashable {
    public let action: (any CleanupActionProtocol)?
    public let toolID: ToolID
    public let estimatedSavingsBytes: UInt64

    public var id: String { toolID.rawValue }

    /// Display name for the row. Falls back to the tool ID if the action
    /// is nil (diagnostic-only entries without a registered cleanup).
    public var displayName: String {
        action?.displayName ?? toolID.rawValue.capitalized
    }

    /// Current reclaimable bytes formatted with `ByteCountFormatter`.
    public var reclaimableFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedSavingsBytes), countStyle: .binary)
    }

    public init(action: (any CleanupActionProtocol)?, toolID: ToolID, estimatedSavingsBytes: UInt64) {
        self.action = action
        self.toolID = toolID
        self.estimatedSavingsBytes = estimatedSavingsBytes
    }

    public static func == (lhs: CleanupOpportunity, rhs: CleanupOpportunity) -> Bool {
        lhs.id == rhs.id && lhs.toolID == rhs.toolID && lhs.estimatedSavingsBytes == rhs.estimatedSavingsBytes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(toolID)
        hasher.combine(estimatedSavingsBytes)
    }
}

/// Result of a dry-run, stored in `CleanupViewModel.preview` and rendered
/// by the CleanupView's preview sheet.
public struct CleanupPreview: Identifiable {
    public let id = UUID()
    public let opportunity: CleanupOpportunity?
    public let report: DryRunReport

    public init(opportunity: CleanupOpportunity?, report: DryRunReport) {
        self.opportunity = opportunity
        self.report = report
    }

    /// Number of candidate paths in the report.
    public var candidateCount: Int { report.candidatePaths.count }

    /// Formatted total reclaimable bytes.
    public var totalFormatted: String {
        ByteCountFormatter.string(fromByteCount: report.totalReclaimableBytes, countStyle: .binary)
    }
}

// MARK: - Preview stub

/// Minimal `AppEnvironment` for SwiftUI previews. Since `AppEnvironment`
/// is `final` (can't subclass), the preview builds one via the public
/// initializer with stub implementations for every protocol slot.
/// Marked `@MainActor` because `AppEnvironment.init` is main-actor
/// isolated and `preview()` below is already `@MainActor`.
@MainActor
private func makePreviewAppEnvironment() -> AppEnvironment {
    AppEnvironment(
        detectorRegistry: PreviewStubDetectorRegistry(),
        diagnosticsEngine: PreviewStubDiagnosticsEngine(),
        persistenceController: PreviewStubPersistence(),
        cleanupServiceRegistry: PreviewStubCleanupRegistry(),
        updateProviderRegistry: PreviewStubUpdaterRegistry()
    )
}

private final class PreviewStubCleanupRegistry: ForgeCore.CleanupServiceRegistryProtocol {
    func availableActions() async -> [any ForgeCore.CleanupActionProtocol] {
        [PreviewDerivedDataAction()]
    }
}

private struct PreviewDerivedDataAction: ForgeCore.CleanupActionProtocol, ForgeCore.TrashOnly {
    let id = "xcode.derivedData"
    let displayName = "DerivedData"
    func dryRun() async throws -> ForgeCore.DryRunReport {
        ForgeCore.DryRunReport(
            target: "DerivedData",
            candidatePaths: [URL(fileURLWithPath: "/tmp/preview/Build")],
            totalReclaimableBytes: 18_400_000_000
        )
    }
}

private final class PreviewStubDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] {
        [
            DiagnosticIssue(
                toolID: .xcode,
                title: "Xcode DerivedData",
                explanation: "Build artifacts have accumulated.",
                severity: .critical,
                estimatedSavingsBytes: 18_400_000_000
            ),
            DiagnosticIssue(
                toolID: .docker,
                title: "Docker images",
                explanation: "Old images.",
                severity: .warning,
                estimatedSavingsBytes: 12_000_000_000
            )
        ]
    }
    func analyze(toolID: ForgeCore.ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}

private final class PreviewStubDetectorRegistry: ForgeCore.DetectorRegistryProtocol {
    func scanAll() async throws -> [ForgeCore.ToolDetection] { [] }
    func register(_ detector: any ForgeCore.ToolDetectorProtocol) async {}
}

private final class PreviewStubPersistence: ForgeCore.PersistenceControllerProtocol {
    let container: ModelContainer
    init() {
        let schema = Schema([ToolRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(for: schema, configurations: [config])
    }
    func save(_ records: [ToolRecord]) throws {}
    func fetchAll() throws -> [ToolRecord] { [] }
}

private final class PreviewStubUpdaterRegistry: ForgeCore.UpdateProviderRegistryProtocol {
    func latestVersion(for toolID: ForgeCore.ToolID) async throws -> ForgeCore.SemVer? { nil }
}
