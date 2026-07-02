import SwiftUI
import ForgeCore
import ForgeDesign

/// Overview screen — environment health at a glance.
///
/// Real content (health score, healthy/warning/critical counts, potential
/// cleanup, recent issues) lands in Phase 4G. This Phase 4E commit is a
/// scaffold that proves the navigation wiring works.
public struct OverviewView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Overview",
                subtitle: "Environment health at a glance"
            )
            ForgeCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Phase 4G")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textSecondary)
                    Text("Health score, cleanup estimate, and recent issues arrive in the next phase.")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
