import Foundation
import ForgeCore

/// Lightweight, UI-ready representation of a detected developer tool.
public struct ToolUIModel: Identifiable, Hashable, Sendable {
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
}
