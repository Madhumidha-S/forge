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

    @State private var sortField: ToolsSortField = .name
    @State private var sortDirection: SortDirection = .ascending

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
        .toolbar {
            // Custom sort UI in the toolbar. The macOS 14 `Table` type-checker
            // can't handle 6 columns × `value:` keypaths × `sortOrder:`
            // binding, so clickable column-header sorting is off the table.
            // A toolbar dropdown sidesteps the generic entirely while still
            // giving the user full sort UX (field + direction).
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .onChange(of: sortField) { _, _ in applySort() }
        .onChange(of: sortDirection) { _, _ in applySort() }
    }

    /// Sort dropdown — two inline pickers (field + direction) plus a
    /// label showing the current sort.
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortField) {
                ForEach(ToolsSortField.allCases) { field in
                    Label(field.label, systemImage: field.systemImage).tag(field)
                }
            }
            Picker("Order", selection: $sortDirection) {
                Text("Ascending").tag(SortDirection.ascending)
                Text("Descending").tag(SortDirection.descending)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
    }

    /// Re-sorts the tool list using the current `sortField` +
    /// `sortDirection`. `KeyPathComparator` handles optional types (nil
    /// sorts to one end depending on direction). Delegates to
    /// `viewModel.sort(by:)` because `tools` is `private(set)` and can't
    /// be mutated in place from outside the view model.
    private func applySort() {
        let order: SortOrder = sortDirection == .ascending ? .forward : .reverse
        let comparator: KeyPathComparator<ToolUIModel>
        switch sortField {
        case .name:
            comparator = KeyPathComparator(\ToolUIModel.displayName, order: order)
        case .version:
            comparator = KeyPathComparator(\ToolUIModel.version, order: order)
        case .diskUsage:
            comparator = KeyPathComparator(\ToolUIModel.diskUsageBytes, order: order)
        case .lastChecked:
            comparator = KeyPathComparator(\ToolUIModel.lastChecked, order: order)
        }
        viewModel.sort(by: comparator)
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

// MARK: - Sort types

/// Fields the user can sort the Tools table by. Each case maps to a
/// `KeyPath` on `ToolUIModel`; the sort comparator is built in
/// `applySort()`.
enum ToolsSortField: String, CaseIterable, Identifiable, Hashable {
    case name
    case version
    case diskUsage
    case lastChecked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name:        return "Name"
        case .version:     return "Version"
        case .diskUsage:   return "Disk Usage"
        case .lastChecked: return "Last Checked"
        }
    }

    var systemImage: String {
        switch self {
        case .name:        return "textformat"
        case .version:     return "number"
        case .diskUsage:   return "internaldrive"
        case .lastChecked: return "clock"
        }
    }
}

/// Sort direction for the Tools table.
enum SortDirection: Hashable {
    case ascending
    case descending
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
