import Foundation
import SwiftUI
import ForgeCore
import ForgeDiagnostics

/// View model for the Storage screen. Aggregates the diagnostic issues'
/// estimated savings into the three views the screen renders:
///
/// - `storageByTool`: one bucket per `ToolID`, bytes summed across all
///   issues for that tool. Powers the "Storage by tool" bar chart.
///
/// - `storageByCategory`: groups tools into broader categories
///   (Runtimes / Build Artifacts / Models / Caches / CLI Tools) and sums
///   their estimated savings. Powers the "Storage by category" chart.
///
/// - `reclaimableTrend`: a snapshot of `totalReclaimableBytes` across
///   recent analyses. Phase 4H stores this in-memory (last 20 points);
///   Phase 4J/4K persist to SwiftData if needed. Powers the "Trend"
///   line chart.
///
/// Phase 4H — first ViewModel that derives multi-dimensional aggregations
/// from the diagnostics engine's issue stream for visualization purposes.
@MainActor
public final class StorageViewModel: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalyzedAt: Date?
    @Published public private(set) var storageByTool: [StorageBucket] = []
    @Published public private(set) var storageByCategory: [StorageBucket] = []
    @Published public private(set) var reclaimableTrend: [TrendPoint] = []
    @Published public private(set) var totalReclaimableBytes: UInt64 = 0

    private let diagnosticsEngine: any DiagnosticsEngineProtocol

    public init(diagnosticsEngine: any DiagnosticsEngineProtocol) {
        self.diagnosticsEngine = diagnosticsEngine
    }

    /// Convenience initializer for SwiftUI previews.
    public static func preview() -> StorageViewModel {
        StorageViewModel(diagnosticsEngine: PreviewStubDiagnosticsEngine())
    }

    /// Runs the diagnostics engine and refreshes the aggregations.
    public func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let issues = try await diagnosticsEngine.analyze()
            apply(issues)
            appendTrendSample()
            lastAnalyzedAt = Date()
        } catch {
            apply([])
            lastAnalyzedAt = Date()
        }
    }

    private func apply(_ issues: [DiagnosticIssue]) {
        // By tool: sum estimatedSavingsBytes per ToolID.
        var byTool: [ToolID: UInt64] = [:]
        for issue in issues {
            guard let savings = issue.estimatedSavingsBytes else { continue }
            byTool[issue.toolID, default: 0] += savings
        }
        storageByTool = byTool
            .filter { $0.value > 0 }
            .map { StorageBucket(id: $0.key.rawValue, label: $0.key.rawValue.capitalized, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }

        // By category: group tool IDs into broader buckets.
        storageByCategory = StorageCategory.group(storageByTool)

        totalReclaimableBytes = storageByTool.reduce(UInt64(0)) { $0 + $1.bytes }
    }

    private func appendTrendSample() {
        let now = Date()
        let point = TrendPoint(timestamp: now, bytes: totalReclaimableBytes)
        // Keep the last 20 samples so the trend chart doesn't grow unbounded.
        let next = (reclaimableTrend + [point]).suffix(20)
        reclaimableTrend = Array(next)
    }
}

// MARK: - Value types

/// One bucket of storage data, used by both the by-tool and by-category
/// bar charts.
public struct StorageBucket: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let bytes: UInt64

    public init(id: String, label: String, bytes: UInt64) {
        self.id = id
        self.label = label
        self.bytes = bytes
    }

    public var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }
}

/// One sample in the reclaimable-storage trend line chart.
public struct TrendPoint: Identifiable, Hashable {
    public let id = UUID()
    public let timestamp: Date
    public let bytes: UInt64

    public init(timestamp: Date, bytes: UInt64) {
        self.timestamp = timestamp
        self.bytes = bytes
    }
}

/// Higher-level grouping for the storage-by-category chart. Tools that
/// share a category are summed together.
public enum StorageCategory: String, CaseIterable, Identifiable, Hashable {
    case runtimes = "Runtimes"
    case buildArtifacts = "Build Artifacts"
    case models = "Models"
    case caches = "Caches"
    case cliTools = "CLI Tools"

    public var id: String { rawValue }

    /// Maps a tool ID to its broader category.
    static func category(for toolIDRaw: String) -> StorageCategory {
        switch toolIDRaw {
        case "node", "python", "java":           return .runtimes
        case "flutter", "xcode", "androidStudio": return .buildArtifacts
        case "ollama":                          return .models
        case "homebrew", "git":                 return .cliTools
        case "docker":                          return .caches
        default:                                return .caches
        }
    }

    /// Groups flat tool buckets into category buckets by summing bytes.
    static func group(_ buckets: [StorageBucket]) -> [StorageBucket] {
        var byCategory: [StorageCategory: UInt64] = [:]
        for bucket in buckets {
            let cat = category(for: bucket.id)
            byCategory[cat, default: 0] += bucket.bytes
        }
        return StorageCategory.allCases.compactMap { cat in
            guard let bytes = byCategory[cat], bytes > 0 else { return nil }
            return StorageBucket(id: cat.id, label: cat.rawValue, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
    }
}

// MARK: - Preview stub

private final class PreviewStubDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] {
        [
            DiagnosticIssue(
                toolID: .xcode, title: "Xcode DerivedData",
                explanation: "Build artifacts.", severity: .critical,
                estimatedSavingsBytes: 18_400_000_000
            ),
            DiagnosticIssue(
                toolID: .docker, title: "Docker images",
                explanation: "Old images.", severity: .warning,
                estimatedSavingsBytes: 12_000_000_000
            ),
            DiagnosticIssue(
                toolID: .ollama, title: "Ollama models",
                explanation: "Models.", severity: .warning,
                estimatedSavingsBytes: 6_800_000_000
            ),
            DiagnosticIssue(
                toolID: .flutter, title: "Pub cache",
                explanation: "Cache.", severity: .info,
                estimatedSavingsBytes: 2_100_000_000
            )
        ]
    }
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}
