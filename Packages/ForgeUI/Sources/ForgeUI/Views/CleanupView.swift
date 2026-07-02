import SwiftUI
import ForgeCore
import ForgeDesign

/// Cleanup screen — cleanup opportunities with dry-run previews.
///
/// Phase 4 ships dry-run only. The Preview button shows a sheet listing
/// exactly what would be touched; no silent destructive ops. Real content
/// lands in Phase 4J.
public struct CleanupView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Cleanup",
                subtitle: "Dry-run cleanup plans — nothing destructive yet"
            )
            ForgeCard {
                Text("Phase 4J")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
