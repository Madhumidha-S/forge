import SwiftUI

/// Semantic color tokens for the Forge design system.
///
/// These are wrapper accessors around colors defined in
/// `Assets.xcassets` (light/dark variants handled by the asset catalog).
/// Use these instead of hardcoded `.red`, `.secondary`, etc. in the UI
/// so the palette stays consistent and dark-mode is handled by the
/// catalog, not the code.
public enum Palette {
    /// Primary accent color. Uses the system accent so the app adapts
    /// to the user's macOS accent choice (blue / purple / pink / etc.)
    /// instead of imposing a fixed brand color. Keeps the UI calm and
    /// native-feeling rather than looking like a custom-skinned app.
    public static let accent = Color.accentColor

    /// Legacy alias for the accent color. Existing code that referenced
    /// `Palette.brand` now resolves to the system accent (no custom
    /// brand color is enforced — see the doc comment on `accent`).
    public static let brand = Color.accentColor

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

    // MARK: - Convenience colors (system-provided, not in catalog)

    /// Window background — the base color behind all content.
    public static let windowBackground = Color(nsColor: .windowBackgroundColor)

    /// Control background — for input controls and grouped content.
    public static let controlBackground = Color(nsColor: .controlBackgroundColor)

    /// Under-page background — visible behind translucent content.
    public static let underPageBackground = Color(nsColor: .underPageBackgroundColor)

    /// Separator color for dividers between UI regions.
    public static let separator = Color(nsColor: .separatorColor)

    /// Primary label color — adapts to light/dark mode automatically.
    public static let label = Color(nsColor: .labelColor)

    /// Secondary label color — for less prominent text.
    public static let secondaryLabel = Color(nsColor: .secondaryLabelColor)

    /// Tertiary label color — for the least prominent text (placeholders, disabled).
    public static let tertiaryLabel = Color(nsColor: .tertiaryLabelColor)
}
