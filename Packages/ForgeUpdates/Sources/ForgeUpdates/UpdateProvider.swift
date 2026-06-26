import Foundation
import ForgeCore

/// A source that can determine the latest available version of a developer tool.
///
/// Implementations are stateless and `Sendable`; they may perform network
/// I/O, parse local manifests, or shell out to package managers.
public protocol UpdateProvider: Sendable {
    /// Stable identifier for the source (e.g. "github.releases", "homebrew.formula").
    var id: String { get }
    /// Human-readable name shown in the UI.
    var displayName: String { get }
    /// Returns the latest upstream version string for `toolId`, or throws on failure.
    func latestVersion(for toolId: ToolID) async throws -> String
}
