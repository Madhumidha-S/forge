import SwiftUI

/// Typography tokens for the Forge design system.
///
/// Hierarchy scale tuned for professional, dense macOS layouts. All
/// values use `.rounded` design for a softer feel consistent with
/// modern Apple apps (Finder, Mail, Messages). Sizes are explicit
/// `.system(size:)` values rather than text-style names so the
/// hierarchy reads the same regardless of user Dynamic Type settings.
///
/// Scale:
///   displayLarge   32  semibold   big stat readouts (health %)
///   title          24  semibold   screen titles
///   title2         20  semibold   section headers
///   title3         17  medium     subsection headers, card titles
///   headline       15  medium     prominent labels, button text
///   body           13  regular    body text
///   callout        12  regular    secondary body
///   footnote       11  regular    footnotes
///   caption        11  medium     captions, labels
///   caption2       10  medium     tiny labels, section eyebrows
public enum Typography {
    public static let displayLarge = Font.system(size: 32, weight: .semibold, design: .rounded)
    public static let title        = Font.system(size: 24, weight: .semibold, design: .rounded)
    public static let title2       = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let title3       = Font.system(size: 17, weight: .medium,   design: .rounded)
    public static let headline     = Font.system(size: 15, weight: .medium,   design: .rounded)
    public static let body         = Font.system(size: 13, weight: .regular,  design: .rounded)
    public static let callout      = Font.system(size: 12, weight: .regular,  design: .rounded)
    public static let footnote     = Font.system(size: 11, weight: .regular,  design: .rounded)
    public static let caption      = Font.system(size: 11, weight: .medium,   design: .rounded)
    public static let caption2     = Font.system(size: 10, weight: .medium,   design: .rounded)

    /// Monospaced digit font for stat readouts and version numbers —
    /// preserves column alignment.
    public static let monospacedDigit = Font.system(size: 13, weight: .medium, design: .rounded).monospacedDigit()

    /// Larger monospaced digit font for prominent stat values
    /// (e.g. "124 GB" in a metric card).
    public static let monospacedDigitLarge = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()

    /// Section eyebrow — uppercase, tracked, medium weight. Used for
    /// the small labels above each major section.
    public static func eyebrow() -> some View {
        EmptyView()
    }
}
