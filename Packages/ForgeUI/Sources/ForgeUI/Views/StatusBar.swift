import SwiftUI
import ForgeCore
import ForgeDesign

/// Thin status strip pinned to the bottom of the main window.
///
/// Intentionally minimal — every meaningful piece of environment status
/// (health, scan time, critical/warning counts, reclaimable bytes) lives
/// on the Overview page or in each section's toolbar. The bottom strip
/// exists only to anchor the window and confirm that Forge is running,
/// in the spirit of an Xcode / Mail status footer.
public struct StatusBar: View {
    @EnvironmentObject private var toolsVM: ToolsViewModel

    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.m) {
            // Brand mark — quiet, sets the visual anchor without
            // shouting.
            Image(systemName: "hammer.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Palette.tertiaryLabel)

            Text("\(toolsVM.totalCount) tool\(toolsVM.totalCount == 1 ? "" : "s") detected")
                .font(Typography.caption2)
                .foregroundStyle(Palette.tertiaryLabel)
                .monospacedDigit()

            Spacer()

            if let lastScan = toolsVM.lastScanDate {
                Text("scanned \(lastScan.formatted(.relative(presentation: .named)))")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.tertiaryLabel)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
