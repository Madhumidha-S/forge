import SwiftUI

/// Reusable surface views for the Forge design system.
///
/// These are the "molecules" that every section uses: cards that group
/// content, section headers that introduce a group of fields, key-value
/// rows for the inspector panel, and small badges for status pills.
public struct ForgeCard<Content: View>: View {
    private let padding: CGFloat
    private let content: () -> Content

    public init(padding: CGFloat = Spacing.l, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .stroke(Palette.border, lineWidth: 0.5)
            )
    }
}

/// Section header — title on the left, optional subtitle below.
public struct SectionHeader: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

/// Key-value row for the inspector panel.
public struct KeyValueRow: View {
    private let label: String
    private let value: String

    public init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

/// Small status pill — used for severity indicators, tool status, etc.
public struct StatusBadge: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(Typography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}
