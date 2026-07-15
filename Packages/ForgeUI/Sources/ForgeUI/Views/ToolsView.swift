import SwiftUI
import AppKit
import ForgeCore
import ForgeDesign

/// Tools — Activity Monitor style.
///
/// A dense native table listing every detected developer tool. Layout
/// follows Activity Monitor's idiom: small text, monospaced numeric
/// columns right-aligned, status shown as a tiny inline dot, and a
/// minimal toolbar.
///
/// Toolbar:
///   ● Healthy · 2m ago        [All ▾]    Sort ▾     ⟳
///
/// Selection drives the inspector column.
public struct ToolsView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var viewModel: ToolsViewModel
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var environment: AppEnvironment

    @State private var sortField: ToolsSortField = .name
    @State private var sortDirection: SortDirection = .ascending
    @State private var searchQuery: String = ""
    @State private var statusFilter: StatusFilter = .all

    public init() {}

    public var body: some View {
        ZStack {
            if viewModel.tools.isEmpty && !viewModel.isLoading {
                EmptyState(
                    systemImage: "wrench.and.screwdriver",
                    title: "No tools detected",
                    description: "Click Refresh to scan your system for installed developer tools."
                ) {
                    Button("Scan Now") {
                        Task { await viewModel.refresh() }
                    }
                    .controlSize(.regular)
                }
            } else {
                tableContent
            }
        }
        .navigationTitle("Tools")
        .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search tools")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarStatus(
                    status: viewModel.healthyCount == viewModel.totalCount && viewModel.totalCount > 0 ? .healthy
                           : viewModel.totalCount == 0 ? .idle
                           : .warnings,
                    lastScanRelative: viewModel.lastScanDate.flatMap(Self.relativeString(from:))
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                statusFilterMenu

                sortMenu

                Divider().frame(height: 16)

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .help("Refresh tools")
            }
        }
        .contextMenu(forSelectionType: ToolUIModel.ID.self) { ids in
            if let id = ids.first, let tool = viewModel.tools.first(where: { $0.id == id }) {
                Button("Open in Finder") {
                    if let path = tool.installPath {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [URL(fileURLWithPath: path)]
                        )
                    }
                }
                .disabled(tool.installPath == nil)

                Button("Copy Path") {
                    if let path = tool.installPath {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(path, forType: .string)
                    }
                }
                .disabled(tool.installPath == nil)

                Divider()

                Button("Analyze Storage") {
                    Task {
                        if let toolID = ToolID(rawValue: tool.toolIdRaw) {
                            _ = try? await environment.diagnosticsEngine.analyze(toolID: toolID)
                            activityStore.info("Analyzed storage for \(tool.displayName)")
                        }
                    }
                }
            }
        }
        .onChange(of: sortField) { _, _ in applySort() }
        .onChange(of: sortDirection) { _, _ in applySort() }
    }

    /// Native Table — five columns. Numeric columns (Version, Disk
    /// Usage) are right-aligned and monospaced. Cell font is small and
    /// regular-weight for Activity Monitor density.
    private var tableContent: some View {
        Table(filteredTools, selection: selectedToolIDBinding) {
            TableColumn("Tool") { tool in
                ToolNameCell(tool: tool)
            }
            .width(min: 180, ideal: 240)

            TableColumn("Version") { tool in
                VersionCell(tool: tool)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Status") { tool in
                StatusCell(tool: tool)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Disk Usage") { tool in
                DiskUsageCell(tool: tool)
            }
            .width(min: 90, ideal: 110)

            TableColumn("Last Checked") { tool in
                LastCheckedCell(tool: tool)
            }
            .width(min: 100, ideal: 130)
        }
        .tableStyle(.inset)
        .controlSize(.small)
    }

    private var filteredTools: [ToolUIModel] {
        var tools = viewModel.tools
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            tools = tools.filter {
                $0.displayName.lowercased().contains(q) ||
                ($0.version ?? "").lowercased().contains(q)
            }
        }
        switch statusFilter {
        case .all:
            break
        case .healthy:
            tools = tools.filter { $0.isHealthy }
        case .unhealthy:
            tools = tools.filter { !$0.isHealthy }
        }
        return tools
    }

    /// Status filter menu — single Menu button labeled with the current
    /// filter, replacing the segmented picker for a more native,
    /// compact toolbar. Activity Monitor uses popup menus rather than
    /// segmented controls.
    private var statusFilterMenu: some View {
        Menu {
            Button {
                statusFilter = .all
            } label: {
                if statusFilter == .all {
                    Label("All", systemImage: "checkmark")
                } else {
                    Text("All")
                }
            }
            Button {
                statusFilter = .healthy
            } label: {
                if statusFilter == .healthy {
                    Label("Healthy", systemImage: "checkmark")
                } else {
                    Text("Healthy")
                }
            }
            Button {
                statusFilter = .unhealthy
            } label: {
                if statusFilter == .unhealthy {
                    Label("Unhealthy", systemImage: "checkmark")
                } else {
                    Text("Unhealthy")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(statusFilter.label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(Typography.subheadline)
            .foregroundStyle(Palette.textPrimary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    /// Sort dropdown — picker for the field, picker for direction.
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
            HStack(spacing: 4) {
                Text("Sort")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(Typography.subheadline)
            .foregroundStyle(Palette.textPrimary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

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

// MARK: - Column cell views (Activity Monitor density)

/// Small, monospaced cell fonts for Activity Monitor density. Cell
/// font is `subheadline` (12pt regular) — tighter than `body` and
/// what Apple's Activity Monitor uses.
private struct ToolNameCell: View {
    let tool: ToolUIModel

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: tool.systemImageName)
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: 16)
            Text(tool.displayName)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
        }
    }
}

private struct VersionCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.version ?? "—")
            .font(Typography.subheadline.monospacedDigit())
            .foregroundStyle(tool.version == nil ? Palette.textSecondary : Palette.textPrimary)
    }
}

/// Status — tiny inline dot + label. No capsule, no background, no
/// badge. Same vocabulary as Activity Monitor's process state column.
private struct StatusCell: View {
    let tool: ToolUIModel

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tool.isHealthy ? Palette.success : Palette.critical)
                .frame(width: 6, height: 6)
            Text(tool.isHealthy ? "Healthy" : "Unhealthy")
                .font(Typography.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
        }
    }
}

private struct DiskUsageCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.diskUsageFormatted)
            .font(Typography.subheadline.monospacedDigit())
            .foregroundStyle(tool.diskUsageBytes == nil ? Palette.textSecondary : Palette.textPrimary)
    }
}

private struct LastCheckedCell: View {
    let tool: ToolUIModel

    var body: some View {
        Text(tool.lastChecked, style: .relative)
            .font(Typography.subheadline)
            .foregroundStyle(Palette.textSecondary)
    }
}

// MARK: - Sort / filter types

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

enum SortDirection: Hashable {
    case ascending
    case descending
}

enum StatusFilter: Hashable {
    case all
    case healthy
    case unhealthy

    var label: String {
        switch self {
        case .all:       return "All"
        case .healthy:   return "Healthy"
        case .unhealthy: return "Unhealthy"
        }
    }
}

// MARK: - Helpers

extension ToolsView {
    static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
