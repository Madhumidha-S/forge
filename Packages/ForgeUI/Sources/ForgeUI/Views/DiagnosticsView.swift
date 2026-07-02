import SwiftUI
import ForgeCore
import ForgeDesign

/// Diagnostics screen — issues grouped by severity.
///
/// Real content (severity-grouped issue cards with remediation buttons)
/// lands in Phase 4H. This Phase 4E commit is a scaffold.
public struct DiagnosticsView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Diagnostics",
                subtitle: "Issues grouped by severity"
            )
            ForgeCard {
                Text("Phase 4H")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
