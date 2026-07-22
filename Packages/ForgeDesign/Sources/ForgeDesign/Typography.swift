import SwiftUI

/// Typography tokens for the Forge design system.
///
/// Hierarchy scale tuned for native macOS. All values use `.rounded`
/// design for a softer feel consistent with modern Apple apps. Sizes
/// are explicit `.system(size:)` values rather than text-style names
/// so the hierarchy reads the same regardless of user Dynamic Type.
///
/// Weights are intentionally narrow — `regular`, `medium` (reserved
/// for tracked eyebrow labels), and `semibold`. Hierarchy comes from
/// size + spacing, not from piling on bold weights.
///
/// Scale:
///   displayTitle    26  regular   landing page hero title (Overview)
///   title           22  semibold  reserved for in-page emphasis
///   title2          17  semibold  section / subsection header
///   title3          15  medium    row title, inspector header
///   headline        13  semibold  button text, strong label
///   body            13  regular   body text
///   subheadline     12  regular   secondary body, inline status
///   callout         12  regular   inline labels
///   footnote        11  regular   footnotes
///   caption         11  regular   captions
///   caption2        10  medium    tracked eyebrow labels
public enum Typography {
    public static let displayTitle = Font.system(size: 26, weight: .regular,  design: .rounded)
    public static let title        = Font.system(size: 22, weight: .semibold, design: .rounded)
    public static let title2       = Font.system(size: 17, weight: .semibold, design: .rounded)
    public static let title3       = Font.system(size: 15, weight: .medium,   design: .rounded)
    public static let headline     = Font.system(size: 13, weight: .semibold, design: .rounded)
    public static let body         = Font.system(size: 13, weight: .regular,  design: .rounded)
    public static let subheadline  = Font.system(size: 12, weight: .regular,  design: .rounded)
    public static let callout      = Font.system(size: 12, weight: .regular,  design: .rounded)
    public static let footnote     = Font.system(size: 11, weight: .regular,  design: .rounded)
    public static let caption      = Font.system(size: 11, weight: .regular,  design: .rounded)
    public static let caption2     = Font.system(size: 10, weight: .medium,   design: .rounded)

    /// Monospaced digit font for stat readouts and version numbers.
    public static let monospacedDigit = Font.system(size: 12, weight: .regular, design: .rounded).monospacedDigit()

    /// Larger monospaced digit font for prominent stat values
    /// (e.g. "4.2 GB" in a header).
    public static let monospacedDigitLarge = Font.system(size: 17, weight: .regular, design: .rounded).monospacedDigit()
}
