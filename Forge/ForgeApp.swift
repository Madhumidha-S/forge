import SwiftUI
import ForgeCore
import ForgeDetectors
import ForgeDiagnostics
import ForgeUI

@main
struct ForgeApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var toolsViewModel: ToolsViewModel
    @StateObject private var overviewViewModel: OverviewViewModel
    @StateObject private var diagnosticsViewModel: DiagnosticsViewModel
    @StateObject private var storageViewModel: StorageViewModel
    @StateObject private var cleanupViewModel: CleanupViewModel
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

        // Construct every ViewModel up front from the shared environment
        // and inject them via .environmentObject at the scene root. Views
        // read them through @EnvironmentObject so the data is the real
        // data, not a preview stub. Per-view init(viewModel:) fallbacks
        // are gone. Each VM gets an `onEvent` closure that forwards its
        // lifecycle messages to ActivityStore so the Activity screen
        // shows real, correlated events.
        //
        // Access `_activityStore.wrappedValue` directly (the StateObject
        // backing storage, not the property-wrapper accessor) to avoid
        // tripping Swift 6's "escaping closure captures mutating self"
        // check. The `_activityStore` storage is initialised by the
        // `@StateObject ... = ActivityStore()` declaration before this
        // init body runs, so it is safe to read here.
        let store = self._activityStore.wrappedValue
        let log: (String) -> Void = { message in
            store.info(message)
        }

        // Construct toolsViewModel first so overviewVM can capture it for its
        // toolsCountProvider closure (OverviewViewModel reads the live detected
        // tool count to avoid fabricating a hardcoded "8 healthy" stat).
        let viewModel = ToolsViewModel(
            registry: env.detectorRegistry,
            persistence: env.persistenceController,
            onEvent: log
        )
        _toolsViewModel = StateObject(wrappedValue: viewModel)

        let overviewVM = OverviewViewModel(
            diagnosticsEngine: env.diagnosticsEngine,
            onEvent: log,
            toolsCountProvider: { [viewModel] in viewModel.totalCount }
        )
        _overviewViewModel = StateObject(wrappedValue: overviewVM)

        let diagnosticsVM = DiagnosticsViewModel(
            diagnosticsEngine: env.diagnosticsEngine,
            onEvent: log
        )
        _diagnosticsViewModel = StateObject(wrappedValue: diagnosticsVM)

        let storageVM = StorageViewModel(
            diagnosticsEngine: env.diagnosticsEngine,
            onEvent: log
        )
        _storageViewModel = StateObject(wrappedValue: storageVM)

        let cleanupVM = CleanupViewModel(
            environment: env,
            onEvent: log
        )
        _cleanupViewModel = StateObject(wrappedValue: cleanupVM)

        // ---- Launch sequence ----
        // Register all detectors, register all diagnostic providers, then
        // kick off the first scan for every ViewModel.
        Task { @MainActor in
            store.info("Forge launched")

            store.info("Registering \(Self.detectors.count) detectors…")
            for detector in Self.detectors {
                await registry.register(detector)
            }
            store.info("Detectors ready (\(Self.detectors.count))")

            store.info("Registering \(Self.diagnosticProviders.count) diagnostic providers…")
            for provider in Self.diagnosticProviders {
                await liveDiagnostics.register(provider)
            }
            store.info("Diagnostics engine ready (\(Self.diagnosticProviders.count) providers)")

            await viewModel.refresh()
            await overviewVM.analyze()
            await diagnosticsVM.analyze()
            await storageVM.analyze()
            await cleanupVM.refresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(activityStore)
                .environmentObject(settingsStore)
                .environmentObject(toolsViewModel)
                .environmentObject(overviewViewModel)
                .environmentObject(diagnosticsViewModel)
                .environmentObject(storageViewModel)
                .environmentObject(cleanupViewModel)
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
