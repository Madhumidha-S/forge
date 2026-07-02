import SwiftUI

/// View modifiers used across the app for consistent interaction patterns.
public extension View {
    /// Standard card hover effect — subtle background change on hover.
    /// Apply to list rows that should feel interactive.
    func forgeRowHover() -> some View {
        self.modifier(ForgeRowHoverModifier())
    }
}

private struct ForgeRowHoverModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                isHovered ? Palette.surfaceElevated : Color.clear
            )
            .onHover { isHovered = $0 }
    }
}
