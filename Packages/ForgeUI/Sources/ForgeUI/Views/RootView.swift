import SwiftUI
import ForgeCore
import ForgeDesign

/// Top-level view: a single 3-column `NavigationSplitView` shell that
/// stays stable across every section in the app.
///
/// - Sidebar (column 1): `SidebarView` selects the active `AppSection`.
/// - Content (column 2): the active section's main view.
/// - Inspector (column 3): contextual third column that shows the
///   selected item's details, or a calm empty-state placeholder when
///   nothing is selected. The column stays at a fixed comfortable width
///   (~300pt) regardless of selection state so the layout never
///   reflows.
public struct RootView: View {
    @StateObject private var router = AppRouter()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView(
                sidebar: {
                    SidebarView(selection: $router.section)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
                },
                content: {
                    detailView
                        .navigationSplitViewColumnWidth(min: 520, ideal: 760)
                },
                detail: {
                    inspectorView
                        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
                }
            )
            StatusBar()
        }
        .environmentObject(router)
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1000, minHeight: 600)
    }

    /// Middle column: the active section's main view.
    @ViewBuilder
    private var detailView: some View {
        switch router.section {
        case .overview:    OverviewView()
        case .tools:       ToolsView()
        case .diagnostics: DiagnosticsView()
        case .storage:     StorageView()
        case .cleanup:     CleanupView()
        case .activity:    ActivityView()
        case .settings:    SettingsView()
        }
    }

    /// Right column: dispatches to the appropriate inspector view, or
    /// the shared empty-state placeholder when nothing is selected.
    @ViewBuilder
    private var inspectorView: some View {
        switch router.section {
        case .tools:
            if let toolID = router.selectedToolID {
                ToolsInspectorView(toolID: toolID)
            } else {
                InspectorEmptyHint()
            }
        case .diagnostics:
            if let id = router.selectedIssueID {
                DiagnosticsInspectorView(issueID: id)
            } else {
                InspectorEmptyHint()
            }
        case .cleanup:
            if let id = router.selectedOpportunityID {
                CleanupInspectorView(opportunityID: id)
            } else {
                InspectorEmptyHint()
            }
        case .activity:
            if let id = router.selectedActivityEntryID {
                ActivityInspectorView(entryID: id)
            } else {
                InspectorEmptyHint()
            }
        case .overview, .storage, .settings:
            InspectorEmptyHint()
        }
    }
}
