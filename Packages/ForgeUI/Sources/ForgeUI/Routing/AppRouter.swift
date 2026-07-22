import Foundation
import SwiftUI
import ForgeCore

/// Router that owns the top-level navigation state for the Forge app.
///
/// `section` is the currently-selected sidebar item. Per-section
/// inspector selections (`selectedToolID`, `selectedIssueID`,
/// `selectedOpportunityID`, `selectedActivityEntryID`) drive the
/// unified third-column inspector in `RootView`. Each section's
/// selection is stored independently so toggling sections preserves
/// the user's last-selected item per section.
///
/// All selection state is persisted across the lifetime of the app
/// via `@Published` on the router. The router is `@MainActor`-isolated
/// because SwiftUI bindings are main-actor isolated.
@MainActor
public final class AppRouter: ObservableObject {
    @Published public var section: AppSection
    @Published public var selectedToolIDRaw: String?
    @Published public var selectedIssueID: UUID?
    @Published public var selectedOpportunityID: String?
    @Published public var selectedActivityEntryID: UUID?

    public init(
        section: AppSection = .overview,
        selectedToolID: ToolID? = nil,
        selectedIssueID: UUID? = nil,
        selectedOpportunityID: String? = nil,
        selectedActivityEntryID: UUID? = nil
    ) {
        self.section = section
        self.selectedToolIDRaw = selectedToolID?.rawValue
        self.selectedIssueID = selectedIssueID
        self.selectedOpportunityID = selectedOpportunityID
        self.selectedActivityEntryID = selectedActivityEntryID
    }

    /// Convenience accessor for the selected tool, if any.
    public var selectedToolID: ToolID? {
        get {
            guard let raw = selectedToolIDRaw else { return nil }
            return ToolID(rawValue: raw)
        }
        set {
            selectedToolIDRaw = newValue?.rawValue
        }
    }

    /// Select a sidebar section. Clears all inspector selections when
    /// the section changes so the third column starts in its empty
    /// placeholder state for the new section.
    public func selectSection(_ section: AppSection) {
        if self.section != section {
            self.selectedToolIDRaw = nil
            self.selectedIssueID = nil
            self.selectedOpportunityID = nil
            self.selectedActivityEntryID = nil
        }
        self.section = section
    }

    /// Select a tool row in the Tools section. No-op if the current
    /// section is not Tools.
    public func selectTool(_ toolID: ToolID?) {
        guard section == .tools else { return }
        self.selectedToolIDRaw = toolID?.rawValue
    }

    /// Select a diagnostic finding in the Diagnostics section. No-op if
    /// the current section is not Diagnostics.
    public func selectIssue(_ id: UUID?) {
        guard section == .diagnostics else { return }
        self.selectedIssueID = id
    }

    /// Select a cleanup opportunity in the Cleanup section. No-op if
    /// the current section is not Cleanup.
    public func selectOpportunity(_ id: String?) {
        guard section == .cleanup else { return }
        self.selectedOpportunityID = id
    }

    /// Select an activity entry in the Activity section. No-op if the
    /// current section is not Activity.
    public func selectActivityEntry(_ id: UUID?) {
        guard section == .activity else { return }
        self.selectedActivityEntryID = id
    }

    // MARK: - Combined navigation

    /// Combined navigation: switch to Diagnostics and select an issue
    /// in a single call. Use this from views that want to jump
    /// directly to a specific diagnostic finding (e.g. clicking a row
    /// in the Overview's Recent Findings list).
    ///
    /// All `@Published` writes happen in a single synchronous block so
    /// SwiftUI batches them into one update — avoids the runtime
    /// "Publishing changes from within view updates" trap that the
    /// separate `selectSection` + `selectIssue` sequence can hit when
    /// the second publish lands during the first's update pass.
    public func showDiagnosticsIssue(_ id: UUID) {
        self.selectedToolIDRaw = nil
        self.selectedOpportunityID = nil
        self.selectedActivityEntryID = nil
        self.section = .diagnostics
        self.selectedIssueID = id
    }
}
