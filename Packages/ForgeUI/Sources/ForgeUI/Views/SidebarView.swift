import SwiftUI
import ForgeCore
import ForgeDesign

/// Sidebar for the Forge `NavigationSplitView`.
///
/// Renders one row per `AppSection` with the section's SF Symbol and label.
/// Keyboard shortcuts ⌘1–⌘6 are attached to each row via
/// `.keyboardShortcut(...)` so they work regardless of focus.
///
/// The footer is intentionally minimal — three lines: app name, version,
/// platform. Health and last-scan live on the Overview page, not in the
/// sidebar.
public struct SidebarView: View {
    @Binding var selection: AppSection

    public init(selection: Binding<AppSection>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: 0) {
            List(AppSection.allCases, selection: $selection) { section in
                row(for: section)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Forge")

            Divider()

            SidebarFooter()
        }
    }

    /// One row per section. Sections with a `keyboardShortcut` (⌘1–⌘6) get
    /// the `.keyboardShortcut` modifier so they work regardless of focus.
    /// Settings has no shortcut — ⌘, is handled at the RootView level so it
    /// works from anywhere.
    @ViewBuilder
    private func row(for section: AppSection) -> some View {
        let label = Label(section.label, systemImage: section.systemImage)
        if let shortcut = section.keyboardShortcut {
            label.keyboardShortcut(KeyEquivalent(shortcut), modifiers: [.command])
        } else {
            label
        }
    }
}
