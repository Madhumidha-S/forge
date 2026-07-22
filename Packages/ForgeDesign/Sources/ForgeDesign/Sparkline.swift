import SwiftUI

/// Tiny inline trend visualization for a series of values. Renders as
/// a thin polyline that fills under the curve. Used in tool rows,
/// storage tables, and dashboard tiles to convey recent activity at
/// a glance without taking up a full chart's worth of space.
///
/// Renders nothing for an empty series. Otherwise auto-scales the
/// vertical range to the data's actual min/max so trends are visible
/// even when the absolute values are large.
public struct Sparkline: View {
    public let values: [Double]
    public let color: Color
    public let fillOpacity: Double
    public let lineWidth: CGFloat

    public init(
        values: [Double],
        color: Color = Palette.accent,
        fillOpacity: Double = 0.15,
        lineWidth: CGFloat = 1.2
    ) {
        self.values = values
        self.color = color
        self.fillOpacity = fillOpacity
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if values.count >= 2 {
                    let minV = values.min() ?? 0
                    let maxV = values.max() ?? 1
                    let range = max(maxV - minV, 0.0001)
                    let stepX = geo.size.width / CGFloat(values.count - 1)

                    // Filled area under the curve.
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for (idx, value) in values.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let normalized = (value - minV) / range
                            let y = geo.size.height - (CGFloat(normalized) * geo.size.height)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(fillOpacity))

                    // Trend line.
                    Path { path in
                        for (idx, value) in values.enumerated() {
                            let x = CGFloat(idx) * stepX
                            let normalized = (value - minV) / range
                            let y = geo.size.height - (CGFloat(normalized) * geo.size.height)
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

/// Single-row status badge — shows a small dot + label, sized for
/// dense monitoring-style displays (smaller than `StatusBadge`).
public struct StatusPill: View {
    public let dotColor: Color
    public let label: String
    public let isPulsing: Bool

    public init(dotColor: Color, label: String, isPulsing: Bool = false) {
        self.dotColor = dotColor
        self.label = label
        self.isPulsing = isPulsing
    }

    @State private var pulse = false

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .opacity(pulse && isPulsing ? 0.4 : 1.0)
            Text(label)
                .font(Typography.caption2)
                .foregroundStyle(Palette.secondaryLabel)
                .monospacedDigit()
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(Palette.controlBackground)
        )
        .onAppear {
            guard isPulsing else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
