import Foundation
import ForgeCore

/// Lightweight value type that surfaces whether a newer version of a
/// tool is available than what the local detector found.
///
/// The scaffold ships with an empty array; a future ferment will populate
/// it by querying `UpdateProviderRegistryProtocol` and matching results
/// against `ToolDetection.version`.
public struct UpdateAvailabilityEntry: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let toolID: ToolID
    public let currentVersion: String?
    public let availableVersion: String
    public let providerID: String

    public init(
        id: UUID = UUID(),
        toolID: ToolID,
        currentVersion: String?,
        availableVersion: String,
        providerID: String
    ) {
        self.id = id
        self.toolID = toolID
        self.currentVersion = currentVersion
        self.availableVersion = availableVersion
        self.providerID = providerID
    }
}
