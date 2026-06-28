import SwiftUI
import ForgeCore
import ForgeDetectors
import ForgeUI

@main
struct ForgeApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var toolsViewModel: ToolsViewModel

    init() {
        // Build the live detector registry and bridge it to the core protocol.
        let registry = DetectorRegistry()
        let adapter = LiveDetectorRegistryAdapter(actor: registry)
        let env = AppEnvironment.live(detectorRegistry: adapter)
        _environment = StateObject(wrappedValue: env)
        let viewModel = ToolsViewModel(
            registry: env.detectorRegistry,
            persistence: env.persistenceController
        )
        _toolsViewModel = StateObject(wrappedValue: viewModel)

        // Register all detectors and seed the initial scan on launch.
        let detectors: [any ToolDetector] = [
            NodeDetector(),
            PythonDetector(),
            GitDetector(),
            HomebrewDetector(),
            JavaDetector(),
            FlutterDetector(),
            DockerDetector(),
            OllamaDetector()
        ]
        Task { @MainActor in
            for detector in detectors {
                await registry.register(detector)
            }
            await viewModel.refresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: toolsViewModel)
                .environmentObject(environment)
        }
        .modelContainer(environment.persistenceController.container)
        .windowStyle(.titleBar)
    }
}
