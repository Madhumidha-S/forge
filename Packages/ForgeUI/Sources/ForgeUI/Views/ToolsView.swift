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
            VStack(spacing: 0) {
                statsHeader
                Divider()
                content
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

    // MARK: - Sections

    @ViewBuilder
    private var content: some View {
        if toolsViewModel.tools.isEmpty && !toolsViewModel.isLoading {
            emptyState
        } else {
            toolList
        }
    }

    private var toolList: some View {
        List(toolsViewModel.tools) { tool in
            ToolRow(model: tool)
        }
        .overlay {
            if toolsViewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.25)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var statsHeader: some View {
        HStack(alignment: .center, spacing: 28) {
            statBlock(label: "Detected", value: "\(toolsViewModel.totalCount)")
            statBlock(label: "Healthy", value: "\(toolsViewModel.healthyCount)")
            statBlock(label: "Issues", value: "\(toolsViewModel.issuesCount)")
            Spacer()
            if let date = toolsViewModel.lastScanDate {
                statBlock(
                    label: "Last Scan",
                    value: date.formatted(date: .omitted, time: .shortened)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No tools detected yet.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Press Refresh to scan for installed developer tools.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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
