import Foundation
import OSLog
import SwiftData

// MARK: - Protocol Slots

/// Abstract registry that discovers developer tools.
/// Concrete implementations live in `ForgeDetectors`.
public protocol DetectorRegistryProtocol: Sendable {
    /// Run every registered detector and return a collection of results.
    func scanAll() async throws -> [ToolDetection]

    /// Register a detector so it participates in future scans.
    func register(_ detector: any ToolDetectorProtocol) async
}

/// Abstract persistence controller.
/// Concrete implementations live in `ForgePersistence`.
public protocol PersistenceControllerProtocol: Sendable {
    var container: ModelContainer { get }

    /// Persist the supplied tool records (upsert by id).
    @MainActor func save(_ records: [ToolRecord]) throws

    /// Fetch all known tool records.
    @MainActor func fetchAll() throws -> [ToolRecord]
}

/// Abstract registry of safe cleanup actions.
/// Concrete implementations live in `ForgeUtilities`.
public protocol CleanupServiceRegistryProtocol: Sendable {
    /// Return all cleanup actions the user may run.
    func availableActions() async -> [any CleanupActionProtocol]
}

/// Abstract registry of update providers.
/// Concrete implementations live in `ForgeUpdates`.
public protocol UpdateProviderRegistryProtocol: Sendable {
    /// Return the latest known remote version for a tool, if available.
    func latestVersion(for toolID: ToolID) async throws -> SemVer?
}

/// Abstract diagnostics engine. Concrete implementations live in
/// `ForgeDiagnostics`. Phase 4A ships the protocol and a no-op
/// implementation; the real `DiagnosticsEngine` actor lands in Phase 4B.
public protocol DiagnosticsEngineProtocol: Sendable {
    /// Run every registered diagnostics provider and return their issues.
    /// Errors in individual providers are caught and surfaced as a single
    /// `DiagnosticIssue(severity: .warning, …)` so one broken provider
    /// cannot abort the whole analysis.
    func analyze() async throws -> [DiagnosticIssue]

    /// Run only the provider for the given tool, if one is registered.
    /// Returns an empty array when the tool has no registered provider.
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue]

    /// Cancel any in-flight analysis. Safe to call from any isolation.
    func cancel() async
}

// MARK: - Value Types Used by Protocols

/// A lightweight detection result used by the core protocol boundary.
/// Detector packages produce richer `DetectionResult` types and translate them
/// into this shared shape before handing them to ViewModels or persistence.
public struct ToolDetection: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let toolID: ToolID
    public let displayName: String
    public let version: String?
    public let installPath: URL?
    public let diskUsageBytes: UInt64?
    public let isHealthy: Bool

    public init(
        id: UUID = UUID(),
        toolID: ToolID,
        displayName: String,
        version: String? = nil,
        installPath: URL? = nil,
        diskUsageBytes: UInt64? = nil,
        isHealthy: Bool = true
    ) {
        self.id = id
        self.toolID = toolID
        self.displayName = displayName
        self.version = version
        self.installPath = installPath
        self.diskUsageBytes = diskUsageBytes
        self.isHealthy = isHealthy
    }
}

/// Minimal detector protocol used only as a type-erased placeholder in
/// `DetectorRegistryProtocol`. The full contract lives in `ForgeDetectors`.
public protocol ToolDetectorProtocol: Sendable {
    var id: String { get }
    var displayName: String { get }
}

// MARK: - App Environment

/// Central dependency-injection container for the app.
///
/// ViewModels and services receive an `AppEnvironment` rather than concrete
/// implementations, which keeps the UI and core packages decoupled from
/// detectors, persistence, cleanup, and update providers.
@MainActor
public final class AppEnvironment: Sendable, ObservableObject {
    public var detectorRegistry: any DetectorRegistryProtocol
    public var diagnosticsEngine: any DiagnosticsEngineProtocol
    public var persistenceController: any PersistenceControllerProtocol
    public var cleanupServiceRegistry: any CleanupServiceRegistryProtocol
    public var updateProviderRegistry: any UpdateProviderRegistryProtocol

    public init(
        detectorRegistry: any DetectorRegistryProtocol,
        diagnosticsEngine: any DiagnosticsEngineProtocol,
        persistenceController: any PersistenceControllerProtocol,
        cleanupServiceRegistry: any CleanupServiceRegistryProtocol,
        updateProviderRegistry: any UpdateProviderRegistryProtocol
    ) {
        self.detectorRegistry = detectorRegistry
        self.diagnosticsEngine = diagnosticsEngine
        self.persistenceController = persistenceController
        self.cleanupServiceRegistry = cleanupServiceRegistry
        self.updateProviderRegistry = updateProviderRegistry
    }

    /// Builds a live environment using no-op defaults so the app can launch
    /// before every concrete package is fully wired.
    @MainActor
    public static func live(
        detectorRegistry: (any DetectorRegistryProtocol)? = nil
    ) -> AppEnvironment {
        let persistence: any PersistenceControllerProtocol
        if let real = try? PersistenceController() {
            persistence = real
        } else {
            persistence = NoOpPersistenceController()
        }
        return AppEnvironment(
            detectorRegistry: detectorRegistry ?? NoOpDetectorRegistry(),
            diagnosticsEngine: NoOpDiagnosticsEngine(),
            persistenceController: persistence,
            cleanupServiceRegistry: NoOpCleanupServiceRegistry(),
            updateProviderRegistry: NoOpUpdateProviderRegistry()
        )
    }
}

// MARK: - No-Op Defaults

private final class NoOpDetectorRegistry: DetectorRegistryProtocol {
    func scanAll() async throws -> [ToolDetection] { [] }
    func register(_ detector: any ToolDetectorProtocol) async {}
}

@MainActor
final class NoOpPersistenceController: PersistenceControllerProtocol {
    let container: ModelContainer

    init() {
        let schema = Schema([ToolRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: schema, configurations: [config])
    }

    func save(_ records: [ToolRecord]) throws {}
    func fetchAll() throws -> [ToolRecord] { [] }
}

private final class NoOpCleanupServiceRegistry: CleanupServiceRegistryProtocol {
    func availableActions() async -> [any CleanupActionProtocol] { [] }
}

private final class NoOpUpdateProviderRegistry: UpdateProviderRegistryProtocol {
    func latestVersion(for toolID: ToolID) async throws -> SemVer? { nil }
}

private final class NoOpDiagnosticsEngine: DiagnosticsEngineProtocol {
    func analyze() async throws -> [DiagnosticIssue] { [] }
    func analyze(toolID: ToolID) async throws -> [DiagnosticIssue] { [] }
    func cancel() async {}
}
