import SwiftUI
import SwiftData
import ForgeCore
import ForgeDesign

/// Tools screen — native `Table` with 6 columns and an inspector panel.
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
///
/// Sortable columns status
/// -----------------------
/// The `@State sortOrder` and `.onChange(of:)` handler are present so the
/// sort state infrastructure is in place. Phase 4F.1 deliberately omits
/// `Table(sortOrder:)` and the per-column `value:` parameters — the macOS
/// 14 `Table` type-checker hits its time budget on the 6-column generic
/// expression when both are present (every attempt to extract cells /
/// decompose the body hit the same wall). Clickable column-header
/// sorting is deferred to a follow-up that either uses `@TableColumnBuilder`
/// differently or implements a custom sort UI in the toolbar.
public struct ToolsView: View {
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var viewModel: ToolsViewModel

    public init(viewModel: ToolsViewModel? = nil) {
        self.viewModel = viewModel ?? ToolsViewModel(
            registry: PreviewStubRegistry(),
            persistence: PreviewStubPersistence()
        )
    }

    public var body: some View {
        Table(viewModel.tools, selection: selectedToolIDBinding) {
            TableColumn("Tool") { tool in
                ToolNameCell(tool: tool)
            }
            .width(min: 140, ideal: 180)

            TableColumn("Version") { tool in
                VersionCell(tool: tool)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Status") { tool in
                StatusCell(tool: tool)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Disk Usage") { tool in
                DiskUsageCell(tool: tool)
            }
            .width(min: 80, ideal: 110)

            TableColumn("Updates") { tool in
                UpdatesCell(tool: tool)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Last Checked") { tool in
                LastCheckedCell(tool: tool)
            }
            .width(min: 100, ideal: 140)
        }
        .navigationTitle("Tools")
        .searchable(text: .constant(""))

        // Sortable columns: `sortOrder` state and `.onChange` handler
        // were removed in Phase 4F.1 because the macOS 14 `Table`
        // type-checker can't handle 6 columns × `value:` keypaths ×
        // `sortOrder:` binding. Both pieces come back when we wire
        // clickable sorting — see Phase 4F.1 commit message.
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

// MARK: - Column cell views

/// Tool icon + name. Renders inside the "Tool" column.
private struct ToolNameCell: View {
    let tool: ToolUIModel

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: tool.systemImageName)
                .foregroundStyle(Palette.accent)
            Text(tool.displayName)
        }
    }
}

/// Version string, "—" when unknown. Monospaced digit font for alignment.
private struct VersionCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.version ?? "—")
            .foregroundStyle(tool.version == nil ? Palette.textSecondary : Palette.textPrimary)
            .monospacedDigit()
    }
}

/// "Healthy" / "Unhealthy" pill in the Status column.
private struct StatusCell: View {
    let tool: ToolUIModel

    var body: some View {
        StatusBadge(
            tool.isHealthy ? "Healthy" : "Unhealthy",
            color: tool.isHealthy ? Palette.success : Palette.critical
        )
    }
}

/// Human-readable disk-usage string, "—" when unknown.
private struct DiskUsageCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.diskUsageFormatted)
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
    }
}

/// "Available" / "Up to date" text in the Updates column.
private struct UpdatesCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.hasUpdate ? "Available" : "Up to date")
            .foregroundStyle(tool.hasUpdate ? Palette.warning : Palette.textSecondary)
    }
}

/// Relative timestamp in the Last Checked column.
private struct LastCheckedCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.lastChecked, style: .relative)
            .foregroundStyle(Palette.textSecondary)
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
