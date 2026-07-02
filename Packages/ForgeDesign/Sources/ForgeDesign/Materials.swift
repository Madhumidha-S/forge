import SwiftUI

/// Thin wrappers around SwiftUI's `Material` types, used for surface
/// backgrounds that need vibrancy (sidebar, inspector, overlays).
public enum ForgeMaterial {
    /// Light translucency — for sidebar and inspector backgrounds that
    /// sit over window chrome.
    public static let sidebar = Material.regular

    /// Thinner translucency — for inline overlays and dropdowns.
    public static let thinOverlay = Material.thin
}
