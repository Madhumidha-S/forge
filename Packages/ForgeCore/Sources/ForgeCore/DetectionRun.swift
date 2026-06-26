import Foundation
import SwiftData

/// Metadata about a single detector scan operation.
@Model
public final class DetectionRun {
    @Attribute(.unique) public var id: UUID
    public var scanStartedAt: Date
    public var scanFinishedAt: Date?
    public var toolsFound: Int
    public var toolsFailed: Int

    public init(
        id: UUID = UUID(),
        scanStartedAt: Date = Date(),
        scanFinishedAt: Date? = nil,
        toolsFound: Int = 0,
        toolsFailed: Int = 0
    ) {
        self.id = id
        self.scanStartedAt = scanStartedAt
        self.scanFinishedAt = scanFinishedAt
        self.toolsFound = toolsFound
        self.toolsFailed = toolsFailed
    }
}
