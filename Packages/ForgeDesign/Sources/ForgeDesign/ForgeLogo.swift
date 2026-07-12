import SwiftUI

/// Forge brand logo — a custom glyph combining a hammer shape (the
/// "forge" reference) with the brand amber color. Used in the sidebar
/// footer, login window, About panel, and any place that needs to
/// signal "this is Forge".
///
/// Renders as an SF Symbol (`hammer.fill`) tinted with the brand color
/// by default. A larger variant uses `flame.fill` for the splash /
/// about-panel context where a more distinctive silhouette is wanted.
public struct ForgeLogo: View {
    public enum Style {
        /// Small inline mark — sidebar footer, app menu, list bullets.
        case compact
        /// Larger hero mark — splash screen, About panel.
        case hero
    }

    let style: Style
    let size: CGFloat?

    public init(style: Style = .compact, size: CGFloat? = nil) {
        self.style = style
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Subtle backdrop for the hero variant — uses the secondary
            // system label color at low opacity so it adapts to light
            // and dark mode without imposing a brand tint.
            if style == .hero {
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Palette.secondaryLabel.opacity(0.12))
                    .frame(
                        width: (size ?? 64) + 24,
                        height: (size ?? 64) + 24
                    )
            }

            Image(systemName: glyph)
                .font(.system(size: resolvedSize, weight: .semibold))
                .foregroundStyle(logoColor)
        }
    }

    private var glyph: String {
        switch style {
        case .compact: "hammer.fill"
        case .hero:    "hammer.fill"
        }
    }

    private var resolvedSize: CGFloat {
        if let size { return size }
        switch style {
        case .compact: return 14
        case .hero:    return 56
        }
    }

    /// Use the system secondary label color so the logo adapts to light
    /// and dark mode and doesn't impose a brand tint on the UI.
    private var logoColor: Color {
        switch style {
        case .compact: Palette.label
        case .hero:    Palette.label
        }
    }
}
