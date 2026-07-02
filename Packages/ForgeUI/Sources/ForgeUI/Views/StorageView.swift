import SwiftUI
import ForgeCore
import ForgeDesign

/// Storage screen — storage by tool, by category, reclaimable, trends.
///
/// Real content (Swift Charts bar/line charts) lands in Phase 4I. This
/// Phase 4E commit is a scaffold.
public struct StorageView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Storage",
                subtitle: "Storage by tool and category"
            )
            ForgeCard {
                Text("Phase 4I")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
