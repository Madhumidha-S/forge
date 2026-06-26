import Foundation
import ForgeCore

/// Stub for resolving the latest version from a Homebrew formula.
///
/// FUTURE PHASE: This stub is intentionally unimplemented. A future
/// increment will replace its body with a call to `brew info --json=v2`
/// for the formula mapped to the requested tool. The scaffold exists
/// only to demonstrate the contract.
public struct HomebrewFormulaProvider: UpdateProvider {
    public let id = "homebrew.formula"
    public let displayName = "Homebrew Formula"

    public init() {}

    public func latestVersion(for toolId: ToolID) async throws -> String {
        throw UpdateProviderError.notImplemented
    }
}
