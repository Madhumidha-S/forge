import SwiftUI

/// Compact stat card used in grid layouts (Overview, Storage, etc).
///
/// Layout: small caption title at the top, large monospaced-digit value
/// below, and an optional trend chip on the trailing edge. The card
/// itself is just a rounded `controlBackgroundColor` rectangle — no
/// border, no shadow — so it nests cleanly inside `ForgeCard` or grids.
public struct MetricCard: View {
    private let title: String
    private let value: String
    private let trend: String?
    private let trendIsPositive: Bool

    public init(
        title: String,
        value: String,
        trend: String? = nil,
        trendIsPositive: Bool = true
    ) {
        self.title = title
        self.value = value
        self.trend = trend
        self.trendIsPositive = trendIsPositive
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                Text(value)
                    .font(Typography.title3)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer(minLength: Spacing.s)
            if let trend {
                trendChip(trend)
            }
        }
        .padding(Spacing.m)
        .frame(minHeight: 70, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    /// Small pill rendered next to the value when a trend string is
    /// supplied. Green for positive deltas, warning color for negative.
    @ViewBuilder
    private func trendChip(_ text: String) -> some View {
        let color = trendIsPositive ? Palette.success : Palette.warning
        Text(text)
            .font(Typography.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xxs)
            .background(
                Capsule().fill(color.opacity(0.12))
            )
    }
}
