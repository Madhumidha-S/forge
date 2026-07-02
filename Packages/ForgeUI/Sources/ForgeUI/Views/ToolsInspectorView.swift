import SwiftUI
import ForgeCore
import ForgeDesign

/// Inspector panel for the Tools section — shows details for a selected
/// tool and exposes actions (Analyze, Cleanup, Open Config, Reveal in Finder).
///
/// Renders nothing when `toolID` doesn't resolve to a known tool. The
/// parent `RootView` is responsible for only showing this view when the
/// current section is `.tools` AND a tool is selected.
public struct ToolsInspectorView: View {
    private let toolID: ToolID

    public init(toolID: ToolID) {
        self.toolID = toolID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header

            ForgeCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    KeyValueRow("ID", toolID.rawValue)
                    KeyValueRow("Version", "—")
                    KeyValueRow("Location", "—")
                    KeyValueRow("Status", "Detecting…")
                }
            }

            ForgeCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Storage").font(Typography.subheadline).foregroundStyle(Palette.textPrimary)
                    Text("—")
                        .font(Typography.title3)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                    Text("Issues").font(Typography.subheadline).foregroundStyle(Palette.textPrimary)
                    Text("0")
                        .font(Typography.title3)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            actionsCard

            Spacer()
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(Typography.title3)
                    .foregroundStyle(Palette.accent)
                Text(toolID.rawValue.capitalized)
                    .font(Typography.title2)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private var actionsCard: some View {
        ForgeCard {
            VStack(spacing: Spacing.s) {
                actionButton("Analyze", systemImage: "stethoscope") {
                    // Phase 4G wires this to the diagnostics engine.
                }
                actionButton("Cleanup", systemImage: "trash") {
                    // Phase 4J wires this to the cleanup preview sheet.
                }
                actionButton("Open Config", systemImage: "doc.text") {
                    // Reveals the tool's config in Finder.
                }
                actionButton("Reveal in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([])
                }
            }
        }
    }

    private func actionButton(
        _ label: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(label)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textTertiary)
                    .font(.caption)
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
