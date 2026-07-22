import SwiftUI
import ForgeCore
import ForgeDesign

/// Inline environment status — colored dot followed by text.
///
/// Borderless and backgroundless, with consistent internal padding so
/// the dot + text sit with the same breathing room as Apple's native
/// toolbar items in Xcode and System Settings. No chrome competes
/// with the page content.
public struct ToolbarStatus: View {
    public enum Status {
        case healthy
        case warnings
        case critical
        case idle
    }

    let status: Status
    let lastScanRelative: String?

    public init(status: Status, lastScanRelative: String?) {
        self.status = status
        self.lastScanRelative = lastScanRelative
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
            if let lastScanRelative {
                Text("·")
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)
                Text(lastScanRelative)
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)
            }
        }
        // Horizontal padding so the dot + text don't hug the toolbar
        // divider or window edge. Vertical padding so the height is
        // consistent with other toolbar items and the row aligns with
        // the page title.
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var color: Color {
        switch status {
        case .healthy:  Palette.success
        case .warnings: Palette.warning
        case .critical: Palette.critical
        case .idle:     Palette.tertiaryLabel
        }
    }

    private var label: String {
        switch status {
        case .healthy:  "Healthy"
        case .warnings: "Warnings"
        case .critical: "Critical"
        case .idle:     "Idle"
        }
    }

    private var accessibilityDescription: String {
        if let lastScanRelative {
            return "\(label), last scan \(lastScanRelative)"
        }
        return label
    }
}
