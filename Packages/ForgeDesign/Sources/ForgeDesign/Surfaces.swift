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

/// Bare status dot — just a colored circle, no label, no background.
/// Used inline in list rows where a `StatusBadge` would be too loud.
public struct StatusDot: View {
    private let color: Color
    private let size: CGFloat

    public init(_ color: Color, size: CGFloat = 7) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Leading-edge severity strip — a 3pt vertical bar on the left edge of
/// a row. Xcode Console / Activity Monitor pattern. Use when severity
/// should be communicated by edge color rather than a dot.
public struct EdgeBar: View {
    private let color: Color
    private let width: CGFloat

    public init(_ color: Color, width: CGFloat = 3) {
        self.color = color
        self.width = width
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
    }
}

/// Inline status indicator — a dot followed by a label, no background,
/// no capsule. Used inside list rows where a pill would be visually
/// loud. Replaces the heavy `StatusBadge` for inline contexts.
public struct InlineStatus: View {
    private let color: Color
    private let label: String
    private let monospaced: Bool

    public init(_ color: Color, _ label: String, monospaced: Bool = false) {
        self.color = color
        self.label = label
        self.monospaced = monospaced
    }

    public var body: some View {
        HStack(spacing: 6) {
            StatusDot(color)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
                .monospacedDigit() // safe even when not numeric; the glyph fallback is monospaced
        }
    }
}

/// Uppercase eyebrow label — Xcode-style "SECTION TITLE" tracked text.
/// Use above a content block to introduce it without using a card.
public struct SectionEyebrow: View {
    private let title: String
    private let trailing: AnyView?

    public init(_ title: String, trailing: (any View)? = nil) {
        self.title = title
        if let trailing {
            self.trailing = AnyView(trailing)
        } else {
            self.trailing = nil
        }
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            Text(title.uppercased())
                .font(Typography.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Palette.tertiaryLabel)
            if let trailing {
                trailing
            }
            Spacer(minLength: 0)
        }
    }
}
