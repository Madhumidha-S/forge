import SwiftUI
import ForgeCore
import ForgeDetectors
import ForgeUI

@main
struct ForgeApp: App {
    @StateObject private var environment: AppEnvironment
    @StateObject private var toolsViewModel: ToolsViewModel

    init() {
        // Build the live detector registry and register NodeDetector at launch.
        let registry = DetectorRegistry()
        Task { @MainActor in
            await registry.register(NodeDetector())
        }

        // Bridge the actor to the core protocol and assemble the live environment.
        let adapter = LiveDetectorRegistryAdapter(actor: registry)
        let env = AppEnvironment.live(detectorRegistry: adapter)
        _environment = StateObject(wrappedValue: env)
        _toolsViewModel = StateObject(
            wrappedValue: ToolsViewModel(
                registry: env.detectorRegistry,
                persistence: env.persistenceController
            )
        )
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
