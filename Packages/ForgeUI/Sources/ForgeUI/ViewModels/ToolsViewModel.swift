import Foundation
import ForgeCore

/// ViewModel that drives the Tools list by scanning detectors and hydrating
/// from persisted SwiftData records.
@MainActor
public final class ToolsViewModel: ObservableObject {
    @Published public private(set) var tools: [ToolUIModel] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String? = nil
    @Published public private(set) var updateAvailability: [UpdateAvailabilityEntry] = []
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var healthyCount: Int = 0
    @Published public private(set) var issuesCount: Int = 0
    @Published public private(set) var lastScanDate: Date? = nil

    private let registry: any DetectorRegistryProtocol
    private let persistence: any PersistenceControllerProtocol
    private let onEvent: ((String) -> Void)?
    private var scanInFlight = false

    public init(
        registry: any DetectorRegistryProtocol,
        persistence: any PersistenceControllerProtocol,
        onEvent: ((String) -> Void)? = nil
    ) {
        self.registry = registry
        self.persistence = persistence
        self.onEvent = onEvent
    }

    /// Re-runs all registered detectors, persists the results, and updates
    /// the published tool list sorted by display name.
    public func refresh() async {
        guard !scanInFlight else { return }
        scanInFlight = true
        // Yield once before mutating @Published state so the writes
        // land outside any in-flight SwiftUI view-update pass and
        // don't trip the "Publishing changes from within view updates"
        // runtime check.
        await Task.yield()
        isLoading = true
        lastError = nil
        defer {
            scanInFlight = false
            isLoading = false
        }

        do {
            let detections = try await registry.scanAll()
            let records = detections.map(ToolUIModel.record(from:))
            try persistence.save(records)
            tools = detections
                .map(ToolUIModel.from(_:))
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
            totalCount = tools.count
            healthyCount = tools.filter { $0.isHealthy }.count
            issuesCount = totalCount - healthyCount
            lastScanDate = tools.map { $0.lastChecked }.max()
            onEvent?("Tool scan complete: \(tools.count) tools, \(healthyCount) healthy")
        } catch {
            lastError = error.localizedDescription
            onEvent?("Tool scan failed: \(error.localizedDescription)")
        }
    }

    /// Loads previously persisted records without running a scan.
    public func loadCached() async {
        do {
            let records = try persistence.fetchAll()
            tools = records
                .map(ToolUIModel.from(_:))
                .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Sorts the current tool list using the given comparator. Provided
    /// as a method (rather than mutating `tools` in place from the view)
    /// because `tools` is `private(set)` — external callers can't trigger
    /// the setter via in-place mutation. The ToolsView's sort dropdown
    /// uses this to reorder rows.
    public func sort(by comparator: KeyPathComparator<ToolUIModel>) {
        tools.sort(using: comparator)
    }

    /// Clears the current error message.
    public func dismissError() {
        lastError = nil
    }
}

extension ToolUIModel {
    /// Maps a detection result into a persisted `ToolRecord`, splitting the
    /// version string into optional major/minor/patch integers.
    fileprivate static func record(from detection: ToolDetection) -> ToolRecord {
        let (major, minor, patch) = parseVersion(detection.version)

        return ToolRecord(
            id: detection.id,
            toolIdRaw: detection.toolID.rawValue,
            displayName: detection.displayName,
            versionMajor: major,
            versionMinor: minor,
            versionPatch: patch,
            installPath: detection.installPath?.path,
            diskUsageBytes: detection.diskUsageBytes.map(Int64.init),
            lastChecked: Date(),
            isHealthy: detection.isHealthy
        )
    }

    /// Splits a version string such as `v20.10.0` or `20.10.0` into its
    /// integer components. Missing or unparseable components are returned as `nil`.
    private static func parseVersion(_ version: String?) -> (Int?, Int?, Int?) {
        guard let version else { return (nil, nil, nil) }

        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed

        let components = withoutPrefix.split(separator: ".", omittingEmptySubsequences: false)
        let major = components.count > 0 ? Int(components[0]) : nil
        let minor = components.count > 1 ? Int(components[1]) : nil
        let patch = components.count > 2 ? Int(components[2]) : nil
        return (major, minor, patch)
    }
}
