import SwiftUI
import SwiftData
import ForgeCore
import ForgeDesign

/// Tools screen — native `Table` with sortable columns and an inspector panel.
///
/// Columns match the architecture doc's wireframe:
/// - Tool
/// - Version
/// - Status
/// - Disk Usage
/// - Updates
/// - Last Checked
///
/// Row selection writes to `AppRouter.selectedToolID`, which the parent
/// `RootView` reads to populate the inspector panel.
public struct ToolsView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var viewModel: ToolsViewModel

    @State private var sortOrder: [KeyPathComparator<ToolUIModel>] = [
        KeyPathComparator(\ToolUIModel.displayName)
    ]

    public init(viewModel: ToolsViewModel? = nil) {
        self.viewModel = viewModel ?? ToolsViewModel(
            registry: PreviewStubRegistry(),
            persistence: PreviewStubPersistence()
        )
    }

    public var body: some View {
        // Columns are inlined directly inside the Table body — not as
        // `some View` computed properties. Decomposing them failed because
        // `TableColumn` (a `TableColumnContent`) doesn't bridge through
        // `some View` inside `@TableColumnBuilder`.
        //
        // Note: no `sortOrder:` binding and no `value:` parameters on the
        // TableColumns. On macOS 14, both trigger an internal
        // `KeyPathComparator` that requires the row type to inherit from
        // `NSObject`; `ToolUIModel` is a struct. Clickable column-header
        // sorting is deferred to Phase 4F — will need either making
        // `ToolUIModel` NSObject-conforming (via an Objective-C bridge) or
        // implementing a custom sort UI.
        Table(viewModel.tools, selection: selectedToolIDBinding) {
            TableColumn("Tool") { (tool: ToolUIModel) in
                HStack(spacing: Spacing.s) {
                    Image(systemName: tool.systemImageName)
                        .foregroundStyle(Palette.accent)
                    Text(tool.displayName)
                }
            }
            .width(min: 140, ideal: 180)

            TableColumn("Version") { (tool: ToolUIModel) in
                Text(tool.version ?? "—")
                    .foregroundStyle(tool.version == nil ? Palette.textSecondary : Palette.textPrimary)
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 100)

            TableColumn("Status") { (tool: ToolUIModel) in
                StatusBadge(
                    tool.isHealthy ? "Healthy" : "Unhealthy",
                    color: tool.isHealthy ? Palette.success : Palette.critical
                )
            }
            .width(min: 80, ideal: 100)

            TableColumn("Disk Usage") { (tool: ToolUIModel) in
                Text(tool.diskUsageFormatted)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
            .width(min: 80, ideal: 110)

            TableColumn("Updates") { (tool: ToolUIModel) in
                Text(tool.hasUpdate ? "Available" : "Up to date")
                    .foregroundStyle(tool.hasUpdate ? Palette.warning : Palette.textSecondary)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Last Checked") { (tool: ToolUIModel) in
                Text(tool.lastChecked, style: .relative)
                    .foregroundStyle(Palette.textSecondary)
            }
            .width(min: 100, ideal: 140)
        }
        .navigationTitle("Tools")
        .searchable(text: .constant(""))
    }

    /// Bridges the table's optional selection into the router. The table
    /// selection type is `ToolUIModel.ID?` (UUID?); the router stores the
    /// raw tool ID string.
    private var selectedToolIDBinding: Binding<ToolUIModel.ID?> {
        Binding(
            get: { router.selectedToolID.flatMap { id in
                viewModel.tools.first(where: { $0.toolIdRaw == id.rawValue })?.id
            }},
            set: { uuid in
                if let uuid, let tool = viewModel.tools.first(where: { $0.id == uuid }) {
                    router.selectTool(ToolID(rawValue: tool.toolIdRaw))
                } else {
                    router.selectTool(nil)
                }
            }
        )
    }
}

// MARK: - Stub bridges

/// Bridges `ToolID` from the core module to the UI module's selection.
private extension ToolID {
    var rawValue: String { ToolIDStorage.rawValue(of: self) }
}

/// Indirection to access `ToolID.rawValue` without `internal` import friction.
private enum ToolIDStorage {
    static func rawValue(of toolID: ToolID) -> String {
        // ToolID is a public enum in ForgeCore with rawValue String, so we
        // can synthesize this through Mirror to avoid coupling.
        let mirror = Mirror(reflecting: toolID)
        for child in mirror.children {
            if let value = child.value as? String { return value }
        }
        return ""
    }
}

private final class PreviewStubRegistry: ForgeCore.DetectorRegistryProtocol {
    func scanAll() async throws -> [ForgeCore.ToolDetection] { [] }
    func register(_ detector: any ForgeCore.ToolDetectorProtocol) async {}
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
