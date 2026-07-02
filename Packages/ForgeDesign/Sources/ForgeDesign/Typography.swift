import SwiftUI

/// Typography tokens for the Forge design system.
///
/// Native SwiftUI fonts, tuned for macOS Sonoma/Tahoe. All values use
/// `.rounded` design for a softer feel consistent with modern Apple apps
/// (Finder, Mail, Messages).
public enum Typography {
    public static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    public static let title = Font.system(.title, design: .rounded).weight(.semibold)
    public static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
    public static let title3 = Font.system(.title3, design: .rounded).weight(.medium)
    public static let headline = Font.system(.headline, design: .rounded)
    public static let body = Font.system(.body, design: .rounded)
    public static let callout = Font.system(.callout, design: .rounded)
    public static let subheadline = Font.system(.subheadline, design: .rounded)
    public static let footnote = Font.system(.footnote, design: .rounded)
    public static let caption = Font.system(.caption, design: .rounded)
    public static let caption2 = Font.system(.caption2, design: .rounded)

    /// Monospaced font for stat readouts and version numbers.
    public static let monospacedDigit = Font.system(.body, design: .rounded).monospacedDigit()
}
