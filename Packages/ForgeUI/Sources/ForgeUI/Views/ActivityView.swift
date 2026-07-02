import SwiftUI
import ForgeCore
import ForgeDesign

/// Activity screen — ring-buffer log of recent app events.
///
/// Backed by OSLog via `Logger`. In-memory ring buffer (last 200 entries);
/// persistence deferred. Real content lands in Phase 4K.
public struct ActivityView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Activity",
                subtitle: "Recent app events"
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
