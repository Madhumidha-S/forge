import SwiftUI
import ForgeCore
import SwiftData

/// Top-level Tools window.
public struct ToolsView: View {
    @ObservedObject private var toolsViewModel: ToolsViewModel

    /// Creates a ToolsView driven by the supplied ViewModel.
    /// If no ViewModel is provided, a stub-backed ViewModel is used so the
    /// view remains previewable and backward-compatible.
    public init(viewModel: ToolsViewModel? = nil) {
        self.toolsViewModel = viewModel ?? ToolsViewModel(
            registry: PreviewStubRegistry(),
            persistence: PreviewStubPersistence()
        )
    }

    public var body: some View {
        NavigationStack {
            List(toolsViewModel.tools) { tool in
                ToolRow(model: tool)
            }
            .navigationTitle("Tools")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await toolsViewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(toolsViewModel.isLoading)
                }
            }
            .task {
                await toolsViewModel.refresh()
            }
            .alert(
                "Refresh failed",
                isPresented: Binding(
                    get: { toolsViewModel.lastError != nil },
                    set: { if !$0 { toolsViewModel.dismissError() } }
                ),
                presenting: toolsViewModel.lastError
            ) { _ in
                Button("OK") {
                    toolsViewModel.dismissError()
                }
            } message: { error in
                Text(error)
            }
        }
    }
}

private final class PreviewStubRegistry: ForgeCore.DetectorRegistryProtocol {
    func register(_ detector: any ForgeCore.ToolDetectorProtocol) async {}
    func scanAll() async throws -> [ForgeCore.ToolDetection] { [] }
}

@MainActor
private final class PreviewStubPersistence: ForgeCore.PersistenceControllerProtocol {
    let container: ModelContainer

    init() {
        let schema = Schema([ToolRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        self.container = try! ModelContainer(for: schema, configurations: [config])
    }

    func save(_ records: [ToolRecord]) throws {}
    func fetchAll() throws -> [ToolRecord] { [] }
}

#if DEBUG
#Preview("preview") {
    let registry = PreviewStubRegistry()
    let persistence = PreviewStubPersistence()
    let viewModel = ToolsViewModel(registry: registry, persistence: persistence)
    ToolsView(viewModel: viewModel)
}
#endif
