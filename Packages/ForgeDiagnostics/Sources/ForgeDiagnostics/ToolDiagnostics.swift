import Foundation
import ForgeCore

/// A diagnostics provider for a single tool.
///
/// Conforming types are responsible for inspecting whatever signal is
/// relevant to their tool — filesystem size, configuration drift, running
/// processes, etc. — and returning the `DiagnosticIssue`s they find.
///
/// Providers are registered with the `DiagnosticsEngine` at startup. They
/// run concurrently inside `withTaskGroup`; a provider's `diagnose(context:)`
/// returning or throwing does not block siblings. Per-provider errors are
/// caught by the engine and surfaced as a single warning `DiagnosticIssue`
/// so one broken provider cannot abort the whole analysis.
public protocol ToolDiagnostics: Sendable {
    /// The tool this provider diagnoses.
    var toolID: ToolID { get }

    /// Runs the provider and returns its issues. May throw; the engine
    /// catches throws and converts them into a warning issue.
    func diagnose(context: DiagnosticsContext) async throws -> [DiagnosticIssue]
}

/// Shared resources passed to every provider during a `diagnose(context:)`
/// invocation. Built once per `analyze()` call so providers can reuse the
/// same `FileManager`, `CommandRunner`, and home-directory reference.
///
/// Providers MUST NOT retain this struct past the lifetime of the
/// `diagnose(context:)` call — the engine may run multiple analyses
/// concurrently and a retained context would alias resources.
///
/// `Sendable` is opted into via `@unchecked` because `FileManager` is not
/// declared `Sendable` by Foundation. The instance is safe to share across
/// actors: the default `FileManager` is documented thread-safe for all
/// operations Forge performs (read-only filesystem queries and stat calls),
/// and providers MUST treat it as a shared read-only resource per the
/// retention rule above.
public struct DiagnosticsContext: @unchecked Sendable {
    public let fileManager: FileManager
    public let commandRunner: any CommandRunner
    public let homeDirectory: URL?

    public init(
        fileManager: FileManager = .default,
        commandRunner: any CommandRunner = ProcessCommandRunner(),
        homeDirectory: URL? = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
        self.homeDirectory = homeDirectory
    }
}
