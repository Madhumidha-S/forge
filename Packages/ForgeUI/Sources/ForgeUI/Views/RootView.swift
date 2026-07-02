import SwiftUI
import ForgeCore
import ForgeDesign

/// Top-level view: NavigationSplitView with sidebar (sections),
/// detail (section content), and inspector (tool details when on Tools).
///
/// The view owns an `AppRouter` for navigation state. The router is
/// injected into child views via `@EnvironmentObject`.
public struct RootView: View {
    @StateObject private var router = AppRouter()

    public init() {}

    public var body: some View {
        NavigationSplitView(
            sidebar: {
                SidebarView(selection: $router.section)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            },
            content: {
                detailView
                    .navigationSplitViewColumnWidth(min: 480, ideal: 640)
            },
            detail: {
                inspectorView
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280)
            }
        )
        .environmentObject(router)
        .frame(minWidth: 800, minHeight: 500)
    }

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

    @ViewBuilder
    private var inspectorView: some View {
        // Inspector is only meaningful for the Tools section. For all other
        // sections we render an empty placeholder so the column collapses
        // to a thin strip rather than holding irrelevant content.
        if router.section == .tools, let toolID = router.selectedToolID {
            ToolsInspectorView(toolID: toolID)
        } else {
            Color.clear
        }
    }
}
