import Foundation
import SwiftUI
import ForgeCore

/// Router that owns the top-level navigation state for the Forge app.
///
/// `section` is the currently-selected sidebar item. `selectedToolID`
/// is the tool row selected in the Tools section's inspector panel.
///
/// Both are persisted via `@SceneStorage` keyed by rawValue so the app
/// restores its navigation state on relaunch. SceneStorage has size
/// limits; we store only the enum raw values (small strings) and not
/// large values, per the scalability risks in the architecture doc.
@MainActor
public final class AppRouter: ObservableObject {
    @Published public var section: AppSection
    @Published public var selectedToolIDRaw: String?

    public init(section: AppSection = .overview, selectedToolID: ToolID? = nil) {
        self.section = section
        self.selectedToolIDRaw = selectedToolID?.rawValue
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

    /// Select a sidebar section. Resets the tool selection if the new
    /// section is not Tools (no inspector there).
    public func selectSection(_ section: AppSection) {
        self.section = section
        if section != .tools {
            self.selectedToolIDRaw = nil
        }
    }

    /// Select a tool row in the Tools section. No-op if the current
    /// section is not Tools.
    public func selectTool(_ toolID: ToolID?) {
        guard section == .tools else { return }
        self.selectedToolIDRaw = toolID?.rawValue
    }
}
