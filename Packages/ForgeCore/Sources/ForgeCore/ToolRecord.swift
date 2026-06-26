import Foundation
import SwiftData

/// Persisted representation of a detected developer tool.
@Model
public final class ToolRecord {
    @Attribute(.unique) public var id: UUID
    public var toolIdRaw: String       // ToolID.rawValue
    public var displayName: String
    public var versionMajor: Int?
    public var versionMinor: Int?
    public var versionPatch: Int?
    public var installPath: String?
    public var diskUsageBytes: Int64?
    public var lastChecked: Date
    public var isHealthy: Bool

    public init(
        id: UUID = UUID(),
        toolIdRaw: String,
        displayName: String,
        versionMajor: Int? = nil,
        versionMinor: Int? = nil,
        versionPatch: Int? = nil,
        installPath: String? = nil,
        diskUsageBytes: Int64? = nil,
        lastChecked: Date = Date(),
        isHealthy: Bool = true
    ) {
        self.id = id
        self.toolIdRaw = toolIdRaw
        self.displayName = displayName
        self.versionMajor = versionMajor
        self.versionMinor = versionMinor
        self.versionPatch = versionPatch
        self.installPath = installPath
        self.diskUsageBytes = diskUsageBytes
        self.lastChecked = lastChecked
        self.isHealthy = isHealthy
    }
}
