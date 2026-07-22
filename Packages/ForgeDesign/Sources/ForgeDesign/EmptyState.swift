import SwiftUI

/// Centered "nothing to show" placeholder with an SF Symbol, title,
/// description, and an optional call-to-action button.
///
/// Proportions tuned to match Apple's empty-state idiom: a sizeable
/// symbol (56pt) sits above a tightly-typeset title and description,
/// centered horizontally and vertically with generous vertical room so
/// the page never feels cramped.
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
        VStack(spacing: Spacing.l) {
            Image(systemName: systemImage)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Palette.tertiaryLabel)
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.title2)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(description)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            action()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}
