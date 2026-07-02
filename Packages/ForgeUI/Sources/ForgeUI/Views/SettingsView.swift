import SwiftUI
import ForgeCore
import ForgeDesign

/// Settings screen — app preferences backed by `@AppStorage` per the
/// architecture doc's resolved decision.
///
/// Real content (refresh interval, auto-update toggle, analytics threshold,
/// About panel) lands in Phase 4K.
public struct SettingsView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Settings",
                subtitle: "App preferences"
            )
            ForgeCard {
                Text("Phase 4K")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
