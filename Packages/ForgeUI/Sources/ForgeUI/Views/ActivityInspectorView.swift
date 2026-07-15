import SwiftUI
import ForgeCore
import ForgeDesign

/// Inspector pane for the Activity screen. Rendered in the third
/// column of `RootView` when an event is selected.
public struct ActivityInspectorView: View {
    @EnvironmentObject private var activityStore: ActivityStore
    let entryID: UUID

    public init(entryID: UUID) {
        self.entryID = entryID
    }

    private var entry: ActivityStore.Entry? {
        activityStore.entries.first { $0.id == entryID }
    }

    public var body: some View {
        Group {
            if let entry {
                EntryDetailContent(
                    entry: entry,
                    severityColor: severityColor(for: entry.level)
                )
            } else {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Event not available")
                        .font(Typography.headline)
                        .foregroundStyle(.secondary)
                    Text("It may have been cleared from the activity log.")
                        .font(Typography.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.xl)
            }
        }
    }

    private func severityColor(for level: ActivityStore.Entry.Level) -> Color {
        switch level {
        case .debug, .info, .notice: return Palette.tertiaryLabel
        case .warning: return Palette.warning
        case .error, .fault: return Palette.critical
        }
    }
}

// MARK: - Detail content

/// Reusable detail layout for a single `ActivityStore.Entry`.
public struct EntryDetailContent: View {
    let entry: ActivityStore.Entry
    let severityColor: Color

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                InspectorSection("Details") {
                    KeyValueRow("Level", entry.level.rawValue.capitalized)
                    KeyValueRow("Time", entry.timestamp.formatted(date: .long, time: .standard))
                    if let subsystem = entry.subsystem {
                        KeyValueRow("Subsystem", subsystem)
                    }
                    KeyValueRow("Relative", entry.timestamp.formatted(.relative(presentation: .named)))
                }

                InspectorSection("Message") {
                    Text(entry.message)
                        .font(Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
    }

    /// Typographic header — small severity dot + message + timestamp.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
                Text(entry.message)
                    .font(Typography.title3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(Typography.caption)
                .foregroundStyle(Palette.tertiaryLabel)
                .monospacedDigit()
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
