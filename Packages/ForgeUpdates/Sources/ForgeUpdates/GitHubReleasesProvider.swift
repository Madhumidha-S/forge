import Foundation
import ForgeCore

/// Stub for fetching latest release tags from GitHub Releases API.
///
/// FUTURE PHASE: This stub is intentionally unimplemented. A future
/// increment will replace its body with a URLSession-based call against
/// `https://api.github.com/repos/{owner}/{repo}/releases/latest` for each
/// known tool. The scaffold exists only to demonstrate the contract.
public struct GitHubReleasesProvider: UpdateProvider {
    public let id = "github.releases"
    public let displayName = "GitHub Releases"

    public init() {}

    public func latestVersion(for toolId: ToolID) async throws -> String {
        throw UpdateProviderError.notImplemented
    }
}
