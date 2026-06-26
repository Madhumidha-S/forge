import Foundation
import ForgeCore

/// Coordinates a collection of update providers so the UI can poll
/// multiple sources concurrently for a tool's latest version.
public actor UpdateProviderRegistry {
    private var providers: [String: any UpdateProvider] = [:]

    public init() {}

    /// Registers a provider, replacing any existing provider with the same `id`.
    public func register(_ provider: any UpdateProvider) {
        providers[provider.id] = provider
    }

    /// Returns all registered provider IDs sorted lexically.
    public func registeredIDs() -> [String] {
        Array(providers.keys).sorted()
    }

    /// Polls every registered provider for `toolId` and returns the
    /// results keyed by provider id. Errors are flattened into the
    /// per-provider result so one broken source doesn't kill the others.
    public func latestVersions(for toolId: ToolID) async -> [String: Result<String, Error>] {
        var results: [String: Result<String, Error>] = [:]
        await withTaskGroup(of: (String, Result<String, Error>).self) { group in
            for provider in providers.values {
                let id = provider.id
                group.addTask {
                    do {
                        let version = try await provider.latestVersion(for: toolId)
                        return (id, .success(version))
                    } catch {
                        return (id, .failure(error))
                    }
                }
            }
            for await (id, result) in group {
                results[id] = result
            }
        }
        return results
    }
}
