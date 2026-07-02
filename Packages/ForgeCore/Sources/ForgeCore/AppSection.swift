import Foundation

/// The top-level sections of the Forge app.
///
/// Each case maps to one sidebar item in the `NavigationSplitView` and one
/// detail view in `RootView`. The order of cases determines the sidebar
/// order — keep it logical (Overview first, Settings last).
public enum AppSection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case tools
    case diagnostics
    case storage
    case cleanup
    case activity
    case settings

    public var id: String { rawValue }

    /// Sidebar label.
    public var label: String {
        switch self {
        case .overview:    return "Overview"
        case .tools:       return "Tools"
        case .diagnostics: return "Diagnostics"
        case .storage:     return "Storage"
        case .cleanup:     return "Cleanup"
        case .activity:    return "Activity"
        case .settings:    return "Settings"
        }
    }

    /// SF Symbol shown in the sidebar and as the section header icon.
    public var systemImage: String {
        switch self {
        case .overview:    return "square.grid.2x2"
        case .tools:       return "wrench.and.screwdriver"
        case .diagnostics: return "stethoscope"
        case .storage:     return "internaldrive"
        case .cleanup:     return "trash"
        case .activity:    return "clock.arrow.circlepath"
        case .settings:    return "gearshape"
        }
    }

    /// Keyboard shortcut character. `nil` means no shortcut
    /// (⌘, for Settings, ⌘0 for sidebar toggle handled separately).
    public var keyboardShortcut: Character? {
        switch self {
        case .overview:    return "1"
        case .tools:       return "2"
        case .diagnostics: return "3"
        case .storage:     return "4"
        case .cleanup:     return "5"
        case .activity:    return "6"
        case .settings:    return nil  // ⌘, handled separately
        }
    }
}
