import Foundation
import ForgeCore

/// Lightweight, UI-ready representation of a detected developer tool.
///
/// Inherits from `NSObject` so that `Table` on macOS 14 can bind
/// `sortOrder:` and use `value:` key-path parameters on its columns —
/// both create internal `KeyPathComparator` instances that require the
/// row type to be `NSObject`-conforming. All stored properties are
/// immutable (`let`), so the class is safe to share across actors
/// (`@unchecked Sendable`); no mutation is possible after construction.
public final class ToolUIModel: NSObject, Identifiable, @unchecked Sendable {
    public let id: UUID
    public let toolIdRaw: String
    public let displayName: String
    public let version: String?
    public let installPath: String?
    public let diskUsageBytes: UInt64?
    public let isHealthy: Bool
    public let lastChecked: Date

    public init(
        id: UUID,
        toolIdRaw: String,
        displayName: String,
        version: String? = nil,
        installPath: String? = nil,
        diskUsageBytes: UInt64? = nil,
        isHealthy: Bool = true,
        lastChecked: Date = Date()
    ) {
        self.id = id
        self.toolIdRaw = toolIdRaw
        self.displayName = displayName
        self.version = version
        self.installPath = installPath
        self.diskUsageBytes = diskUsageBytes
        self.isHealthy = isHealthy
        self.lastChecked = lastChecked
    }

    /// Maps a fresh detection result into a UI model.
    public static func from(_ detection: ToolDetection) -> ToolUIModel {
        ToolUIModel(
            id: detection.id,
            toolIdRaw: detection.toolID.rawValue,
            displayName: detection.displayName,
            version: detection.version,
            installPath: detection.installPath?.path,
            diskUsageBytes: detection.diskUsageBytes,
            isHealthy: detection.isHealthy,
            lastChecked: Date()
        )
    }

    /// Maps a persisted record into a UI model for cold-start hydration.
    public static func from(_ record: ToolRecord) -> ToolUIModel {
        let versionComponents = [record.versionMajor, record.versionMinor, record.versionPatch]
            .compactMap { $0 }
            .map(String.init)
        let version = versionComponents.isEmpty ? nil : versionComponents.joined(separator: ".")

        return ToolUIModel(
            id: record.id,
            toolIdRaw: record.toolIdRaw,
            displayName: record.displayName,
            version: version,
            installPath: record.installPath,
            diskUsageBytes: record.diskUsageBytes.map { UInt64($0) },
            isHealthy: record.isHealthy,
            lastChecked: record.lastChecked
        )
    }

    // MARK: - Computed properties for the Tools table

    /// SF Symbol name for the tool, used in the table's Tool column and
    /// the inspector header. Maps `toolIdRaw` to a symbol; defaults to a
    /// generic wrench for unknown tool IDs.
    public var systemImageName: String {
        switch toolIdRaw {
        case "docker":      return "shippingbox.fill"
        case "flutter":     return "bird"
        case "git":         return "arrow.triangle.branch"
        case "homebrew":    return "mug.fill"
        case "java":        return "cup.and.saucer.fill"
        case "node":        return "n.circle.fill"
        case "ollama":      return "cpu.fill"
        case "python":      return "chevron.left.forwardslash.chevron.right"
        default:            return "wrench.and.screwdriver.fill"
        }
    }

    /// Sortable key for the Status column. Tools with a non-nil version
    /// sort before those without (`.version == nil` renders as "—").
    public var isHealthyText: String {
        isHealthy ? "Healthy" : "Unhealthy"
    }

    /// Sortable key for the Updates column. Phase 4K will wire this to a
    /// real UpdateProvider lookup; for now it's always false.
    public var hasUpdate: Bool { false }
    public var hasUpdateText: String {
        hasUpdate ? "Available" : "Up to date"
    }

    /// Human-readable disk-usage string (e.g. "32.4 GB"). Returns "—"
    /// when the value is unknown.
    public var diskUsageFormatted: String {
        guard let bytes = diskUsageBytes else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useTB, .useKB]
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
