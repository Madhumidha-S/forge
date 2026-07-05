import SwiftUI
import ForgeCore
import ForgeDetectors
import ForgeDiagnostics
import ForgeUI

@main
struct ForgeApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var toolsViewModel: ToolsViewModel
    @StateObject private var activityStore = ActivityStore()
    @StateObject private var settingsStore = SettingsStore()

    init() {
        // ---- Detectors ----
        // Build the live detector registry and bridge it to the core protocol.
        let registry = DetectorRegistry()
        let detectorAdapter = LiveDetectorRegistryAdapter(actor: registry)

        // ---- Diagnostics engine ----
        // Build the actor-backed engine and its @MainActor adapter. Each
        // diagnostic provider scans one tool's on-disk footprint.
        let diagnosticsEngine = DiagnosticsEngine()
        let liveDiagnostics = LiveDiagnosticsEngine(actor: diagnosticsEngine)

        // ---- ToolsViewModel ----
        let env = AppEnvironment.live(
            detectorRegistry: detectorAdapter,
            diagnosticsEngine: liveDiagnostics
        )
        _environment = StateObject(wrappedValue: env)
        let viewModel = ToolsViewModel(
            registry: env.detectorRegistry,
            persistence: env.persistenceController
        )
        _toolsViewModel = StateObject(wrappedValue: viewModel)

        // ---- Launch sequence ----
        // Register all detectors, register all diagnostic providers, then
        // kick off the first scan.
        Task { @MainActor in
            for detector in Self.detectors {
                await registry.register(detector)
            }
            for provider in Self.diagnosticProviders {
                await liveDiagnostics.register(provider)
            }
            await viewModel.refresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(activityStore)
                .environmentObject(settingsStore)
        }
        .modelContainer(environment.persistenceController.container)
        .windowStyle(.titleBar)
    }

    /// All detectors shipped with Forge. Phase 4D was scoped to add
    /// diagnostic providers; a `DetectorManifest` that lives in
    /// `ForgeDetectors` and replaces this hardcoded array is a small
    /// follow-up (Phase 4D follow-up or 4E follow-up).
    private static let detectors: [any ToolDetector] = [
        NodeDetector(),
        PythonDetector(),
        GitDetector(),
        HomebrewDetector(),
        JavaDetector(),
        FlutterDetector(),
        DockerDetector(),
        OllamaDetector()
    ]

    /// All diagnostic providers shipped with Forge. Constructed once with
    /// real home-directory paths so the file-walking providers have
    /// something to scan on first launch. Order is irrelevant — the
    /// engine fans out via withTaskGroup.
    private static let diagnosticProviders: [any ToolDiagnostics] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            XcodeDiagnostics(
                developerDirectory: home.appendingPathComponent("Library/Developer/Xcode", isDirectory: true),
                coreSimulatorDirectory: home.appendingPathComponent("Library/Developer/CoreSimulator", isDirectory: true)
            ),
            DockerDiagnostics(),
            OllamaDiagnostics(),
            FlutterDiagnostics(
                pubCacheDirectory: home.appendingPathComponent(".pub-cache", isDirectory: true),
                buildArtifactsSearchRoot: home
            ),
            HomebrewDiagnostics(),
            AndroidStudioDiagnostics(
                sdkDirectory: home.appendingPathComponent("Library/Android/sdk", isDirectory: true),
                gradleCacheDirectory: home.appendingPathComponent(".gradle/caches", isDirectory: true),
                emulatorDirectory: home.appendingPathComponent(".android/avd", isDirectory: true)
            ),
            GitDiagnostics(),
            PythonDiagnostics()
        ]
    }()
}
