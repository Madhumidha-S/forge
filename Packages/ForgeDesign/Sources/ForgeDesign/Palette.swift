import SwiftUI

/// Semantic color tokens for the Forge design system.
///
/// These are wrapper accessors around colors defined in
/// `Assets.xcassets` (light/dark variants handled by the asset catalog).
/// Use these instead of hardcoded `.red`, `.secondary`, etc. in the UI
/// so the palette stays consistent and dark-mode is handled by the
/// catalog, not the code.
public enum Palette {
    /// Primary accent color — used for selection, links, and the app
    /// icon background. Maps to `AccentColor` in the asset catalog.
    public static let accent = Color.accentColor

    /// Foreground text colors.
    public static let textPrimary = Color("TextPrimary")
    public static let textSecondary = Color("TextSecondary")
    public static let textTertiary = Color("TextTertiary")

    /// Background surface colors.
    public static let surface = Color("Surface")
    public static let surfaceElevated = Color("SurfaceElevated")
    public static let surfaceSidebar = Color("SurfaceSidebar")

    /// Severity colors for diagnostics.
    public static let success = Color("Success")
    public static let warning = Color("Warning")
    public static let critical = Color("Critical")

    /// Border / separator colors.
    public static let border = Color("Border")
}
