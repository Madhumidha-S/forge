import SwiftUI

/// Centered "nothing to show" placeholder with an SF Symbol, title,
/// description, and an optional call-to-action button.
///
/// Used by views whose data is empty (no tools detected, no diagnostics
/// results, etc) so the user sees something instead of a blank pane.
public struct EmptyState<Action: View>: View {
    private let systemImage: String
    private let title: String
    private let description: String
    private let action: () -> Action

    public init(
        systemImage: String,
        title: String,
        description: String,
        @ViewBuilder action: @escaping () -> Action = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(Typography.title3)
                .foregroundStyle(Palette.textPrimary)
            Text(description)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            action()
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(Spacing.l)
    }
}
