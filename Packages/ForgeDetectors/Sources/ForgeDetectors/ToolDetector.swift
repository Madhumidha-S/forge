import Foundation
import ForgeCore

/// A type that can detect the presence, version, and health of a developer tool.
public protocol ToolDetector: Sendable {
    /// Stable identifier used for persistence and telemetry.
    var id: ToolID { get }

    /// Human-readable name shown in the UI.
    var displayName: String { get }

    /// Perform detection. Must not block the calling thread indefinitely;
    /// the registry will cancel the task after the timeout.
    func detect() async throws -> DetectionResult
}
