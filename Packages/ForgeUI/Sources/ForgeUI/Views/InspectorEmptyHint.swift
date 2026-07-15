import SwiftUI
import ForgeCore
import ForgeDesign

/// Empty state for the inspector column when nothing is selected.
///
/// A single, lightly-styled SF Symbol above a one-line hint. The
/// column disappears into the window when there's nothing to show —
/// no card chrome, no colored background, no decorative elements.
public struct InspectorEmptyHint: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(Palette.tertiaryLabel)
            Text("Select an item")
                .font(Typography.caption)
                .foregroundStyle(Palette.tertiaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.windowBackground)
    }
}

/// OS-level summary kept for source compatibility with prior callers
/// that referenced `SystemSummary`. No longer rendered by the UI.
public struct SystemSummary {
    public let osVersion: String
    public let architecture: String

    public var osLine: String { "\(osVersion) · \(architecture)" }

    public static var current: SystemSummary {
        let arch: String
        #if arch(arm64)
        arch = "Apple Silicon"
        #elseif arch(x86_64)
        arch = "Intel"
        #else
        arch = "Unknown"
        #endif
        return SystemSummary(
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: arch
        )
    }
}
