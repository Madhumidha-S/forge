import SwiftUI
import ForgeCore
import ForgeDesign

/// Activity screen — ring-buffer log of recent app events.
///
/// Backed by `ActivityStore` (200-entry ring buffer with OSLog mirror).
/// Renders entries newest-first with a Clear button in the toolbar
/// and a level filter picker. Empty state uses a `ForgeCard`.
public struct ActivityView: View {
    @EnvironmentObject private var activityStore: ActivityStore

    /// Currently selected level filter. `nil` means show all levels.
    @State private var levelFilter: ActivityStore.Entry.Level?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            SectionHeader(
                "Activity",
                subtitle: subtitleText
            )

            if filteredEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker(
                    "Level",
                    selection: $levelFilter
                ) {
                    Text("All").tag(ActivityStore.Entry.Level?.none)
                    ForEach(ActivityStore.Entry.Level.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized)
                            .tag(ActivityStore.Entry.Level?.some(level))
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    activityStore.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(activityStore.entries.isEmpty)
            }
        }
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        let total = activityStore.entries.count
        if total == 0 {
            return "Recent app events"
        }
        return "\(total) entries, in-memory ring buffer (last \(ActivityStore.maxEntries))"
    }

    // MARK: - Filtered entries (newest first)

    private var filteredEntries: [ActivityStore.Entry] {
        let all = activityStore.entries.reversed()
        guard let level = levelFilter else { return Array(all) }
        return all.filter { $0.level == level }
    }

    // MARK: - List

    private var entryList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(filteredEntries) { entry in
                    entryRow(entry)
                }
            }
            .padding(Spacing.m)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .stroke(Palette.border, lineWidth: 0.5)
        )
    }

    private func entryRow(_ entry: ActivityStore.Entry) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: levelIcon(entry.level))
                .foregroundStyle(levelColor(entry.level))
                .font(Typography.body)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.s) {
                    Text(entry.message)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                    Text(entry.timestamp, style: .relative)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .monospacedDigit()
                }
                if let subsystem = entry.subsystem {
                    Text(subsystem)
                        .font(Typography.caption2)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("No activity yet")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("Scans, refreshes, and cleanup actions will appear here.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Level styling

    private func levelIcon(_ level: ActivityStore.Entry.Level) -> String {
        switch level {
        case .debug:   return "circle.fill"
        case .info:    return "info.circle.fill"
        case .notice:  return "bell.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "exclamationmark.octagon.fill"
        case .fault:   return "flame.fill"
        }
    }

    private func levelColor(_ level: ActivityStore.Entry.Level) -> Color {
        switch level {
        case .debug:   return Palette.textTertiary
        case .info:    return .blue
        case .notice:  return .teal
        case .warning: return Palette.warning
        case .error:   return Palette.critical
        case .fault:   return .pink
        }
    }
}
