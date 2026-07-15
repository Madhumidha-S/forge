import SwiftUI
import ForgeCore
import ForgeDesign

/// Activity — Console.app style.
///
/// A live, scrolling log of recent events rendered with monospaced
/// typography and tight timestamps, in the spirit of Apple's Console.
///
/// Layout:
///   ● Healthy · 42 events     [All ▾]      🗑
///
///   TODAY · 5
///   ──────────────────────────────────────────
///   ▎ 14:23:01  Forge launched
///   ▎ 14:23:02  Registering 8 detectors
///   ▎ 14:23:03  Detectors ready
public struct ActivityView: View {
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var router: AppRouter

    @State private var searchQuery = ""
    @State private var levelFilter: LevelFilter = .all

    public init() {}

    public var body: some View {
        Group {
            if activityStore.entries.isEmpty {
                EmptyState(
                    systemImage: "clock.arrow.circlepath",
                    title: "No activity yet",
                    description: "Scans, refreshes, and cleanup actions will appear here as they happen."
                )
            } else if filteredEntries.isEmpty {
                EmptyState(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "No matching events",
                    description: "Adjust your search or filter."
                )
            } else {
                timelineList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Activity")
        .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search events")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarStatus(
                    status: activityStore.entries.contains(where: { $0.level == .error || $0.level == .fault }) ? .critical
                         : activityStore.entries.contains(where: { $0.level == .warning }) ? .warnings
                         : .healthy,
                    lastScanRelative: nil
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                levelFilterMenu

                Divider().frame(height: 16)

                Button(role: .destructive) {
                    activityStore.clear()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(activityStore.entries.isEmpty)
                .help("Clear activity log")
            }
        }
    }

    // MARK: - Filter

    enum LevelFilter: String, Hashable, CaseIterable {
        case all, info, warning, error
        var label: String {
            switch self {
            case .all: "All"
            case .info: "Info"
            case .warning: "Warning"
            case .error: "Error"
            }
        }
    }

    private var filteredEntries: [ActivityStore.Entry] {
        var entries: [ActivityStore.Entry] = Array(activityStore.entries.reversed())
        if levelFilter != .all {
            entries = entries.filter { entry in
                switch levelFilter {
                case .all: return true
                case .info: return entry.level == .info || entry.level == .debug || entry.level == .notice
                case .warning: return entry.level == .warning
                case .error: return entry.level == .error || entry.level == .fault
                }
            }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            entries = entries.filter { entry in
                entry.message.lowercased().contains(q) ||
                (entry.subsystem ?? "").lowercased().contains(q)
            }
        }
        return Array(entries)
    }

    private func severityColor(for level: ActivityStore.Entry.Level) -> Color {
        switch level {
        case .debug, .info, .notice: return Palette.textTertiary
        case .warning: return Palette.warning
        case .error, .fault: return Palette.critical
        }
    }

    // MARK: - Day grouping

    private struct DayGroup: Identifiable {
        let id: String
        let label: String
        let entries: [ActivityStore.Entry]
    }

    private var groupedEntries: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayEntries = filteredEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        let yesterdayEntries = filteredEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: yesterday) }
        let earlierEntries = filteredEntries.filter { $0.timestamp < yesterday }

        var groups: [DayGroup] = []
        if !todayEntries.isEmpty { groups.append(DayGroup(id: "today", label: "Today", entries: todayEntries)) }
        if !yesterdayEntries.isEmpty { groups.append(DayGroup(id: "yesterday", label: "Yesterday", entries: yesterdayEntries)) }
        if !earlierEntries.isEmpty { groups.append(DayGroup(id: "earlier", label: "Earlier", entries: earlierEntries)) }
        return groups
    }

    // MARK: - Timeline list

    private var timelineList: some View {
        List(selection: selectedEntryIDBinding) {
            ForEach(groupedEntries) { group in
                Section {
                    ForEach(group.entries) { entry in
                        ActivityTimelineRow(
                            entry: entry,
                            severityColor: severityColor(for: entry.level)
                        )
                        .tag(entry.id as UUID?)
                    }
                } header: {
                    HStack(spacing: Spacing.s) {
                        Text(group.label.uppercased())
                            .font(Typography.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(Palette.tertiaryLabel)
                        Spacer()
                        Text("\(group.entries.count)")
                            .font(Typography.caption2.monospacedDigit())
                            .foregroundStyle(Palette.tertiaryLabel)
                    }
                    .textCase(nil)
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Level filter menu

    private var levelFilterMenu: some View {
        Menu {
            ForEach(LevelFilter.allCases, id: \.self) { filter in
                Button {
                    levelFilter = filter
                } label: {
                    if levelFilter == filter {
                        Label(filter.label, systemImage: "checkmark")
                    } else {
                        Text(filter.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(levelFilter.label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(Typography.subheadline)
            .foregroundStyle(Palette.textPrimary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Selection

    private var selectedEntryIDBinding: Binding<UUID?> {
        Binding(
            get: { router.selectedActivityEntryID },
            set: { router.selectActivityEntry($0) }
        )
    }

    // MARK: - Row

    /// Console.app-style row. Monospaced timestamp, monospaced
    /// message, severity shown as a 3pt leading edge bar. Very tight
    /// padding.
    private struct ActivityTimelineRow: View {
        let entry: ActivityStore.Entry
        let severityColor: Color

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.s) {
                EdgeBar(severityColor, width: 2)
                    .frame(maxHeight: .infinity)

                Text(timestampString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.tertiaryLabel)
                    .frame(width: 60, alignment: .leading)

                Text(entry.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: Spacing.s)

                if let subsystem = entry.subsystem {
                    Text(subsystem)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.tertiaryLabel)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }

        private var timestampString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: entry.timestamp)
        }
    }
}
