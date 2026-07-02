import Foundation
import ForgeCore

/// `@MainActor` adapter that bridges the actor-based `DiagnosticsEngine`
/// to the `DiagnosticsEngineProtocol` boundary used by `AppEnvironment`.
///
/// Mirrors the pattern of `LiveDetectorRegistryAdapter`: the actor owns the
/// mutable state, the adapter is main-isolated so it fits into SwiftUI's
/// dependency graph and the `@Sendable` existential slot in
/// `AppEnvironment`.
///
/// Registration is intentionally not part of `DiagnosticsEngineProtocol`
/// — only the live adapter exposes `register(_:)`. The protocol is the
/// read-side contract used by ViewModels; the write-side is a startup
/// concern handled by `ForgeApp.init()` once per launch.
@MainActor
public final class LiveDiagnosticsEngine: DiagnosticsEngineProtocol {
    private let actor: DiagnosticsEngine

    public init(actor: DiagnosticsEngine = DiagnosticsEngine()) {
        self.actor = actor
    }

    /// Registers a provider with the underlying actor. Must be called at
    /// startup (typically from `ForgeApp.init()`) before `analyze()` for
    /// the provider to participate in analysis.
    public func register(_ provider: any ToolDiagnostics) async {
        await actor.register(provider)
    }

    public func analyze() async throws -> [DiagnosticIssue] {
        try await actor.analyze()
    }

    public func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] {
        try await actor.analyze(toolID: toolID)
    }

    public func cancel() async {
        await actor.cancel()
    }
}
