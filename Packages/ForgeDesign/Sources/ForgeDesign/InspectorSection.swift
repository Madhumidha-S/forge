import SwiftUI

/// Vertical section block for inspector panels.
///
/// Renders a small uppercase title, a stack of caller-provided rows,
/// and a hairline divider at the bottom. Used to group related fields
/// in `ToolsInspectorView` and any future inspector-style panels.
public struct InspectorSection<Content: View>: View {
    private let title: String
    private let content: () -> Content

    public init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title.uppercased())
                .font(Typography.caption2.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.3)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                content()
            }
            Divider()
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
