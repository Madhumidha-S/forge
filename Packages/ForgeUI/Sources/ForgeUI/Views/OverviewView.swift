import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Overview — Forge's landing page, designed like a system status
/// board rather than a welcome screen. No hero, no marketing copy —
/// just the numbers a developer wants to see at a glance.
///
/// Layout:
///   12 tools   ·   2 warnings   ·   4.2 GB reclaimable
///   ───────────────────────────────────────────────
///   RECENT FINDINGS                                  [3]
///   ───────────────────────────────────────────────
///   Finding row 1
///   Finding row 2
///   Finding row 3
///
///   RECOMMENDED ACTIONS
///   ───────────────────────────────────────────────
///   Action row 1
///   Action row 2
///
///   STORAGE BY TOOL
///   ───────────────────────────────────────────────
///   Tool row 1
///   Tool row 2
public struct OverviewView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var viewModel: OverviewViewModel
    @EnvironmentObject private var toolsViewModel: ToolsViewModel
    @EnvironmentObject private var storageViewModel: StorageViewModel
    @EnvironmentObject private var diagnosticsViewModel: DiagnosticsViewModel

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                summaryHeader
                findingsSection
                actionsSection
                storageSection
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: 900, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.windowBackground)
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarStatus(
                    status: healthStatus,
                    lastScanRelative: viewModel.lastAnalyzedAt.flatMap(Self.relativeString(from:))
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await viewModel.analyze() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isAnalyzing)
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh environment analysis")
            }
        }
        .task {
            if !viewModel.hasScanned {
                await viewModel.analyze()
            }
        }
    }

    // MARK: - Summary header

    /// One-line status summary — tools, issues, reclaimable, all in
    /// monospaced digits. Pure data, no marketing copy. Renders as a
    /// single horizontal row with subtle dot separators between stats.
    private var summaryHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            stat(
                value: "\(toolsViewModel.totalCount)",
                label: toolsViewModel.totalCount == 1 ? "tool" : "tools"
            )
            separator
            stat(
                value: "\(viewModel.criticalCount + viewModel.warningCount)",
                label: viewModel.criticalCount + viewModel.warningCount == 1 ? "issue" : "issues",
                color: (viewModel.criticalCount + viewModel.warningCount) > 0 ? Palette.warning : Palette.textPrimary
            )
            separator
            stat(
                value: ByteCountFormatter.string(
                    fromByteCount: Int64(viewModel.potentialCleanupBytes),
                    countStyle: .binary
                ),
                label: "reclaimable"
            )
            separator
            stat(
                value: viewModel.lastAnalyzedAt.flatMap { lastScanRelativeString(from: $0) } ?? "—",
                label: "last scan",
                color: Palette.textSecondary,
                useMonospacedDigit: false
            )
            Spacer(minLength: 0)
        }
    }

    /// One inline stat block: monospaced number + small label.
    private func stat(value: String, label: String, color: Color = Palette.textPrimary, useMonospacedDigit: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(useMonospacedDigit
                      ? Typography.body.weight(.semibold).monospacedDigit()
                      : Typography.body.weight(.semibold))
                .foregroundStyle(color)
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Palette.tertiaryLabel)
        }
    }

    /// Subtle separator between stats — a bullet character in the
    /// tertiary label color. Quieter than a divider line.
    private var separator: some View {
        Text("·")
            .font(Typography.body)
            .foregroundStyle(Palette.tertiaryLabel)
            .padding(.horizontal, Spacing.s)
    }

    // MARK: - Recent Findings

    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow("Recent Findings")
                Spacer(minLength: 0)
                Text("\(viewModel.recentIssues.count)")
                    .font(Typography.caption2.monospacedDigit())
                    .foregroundStyle(Palette.tertiaryLabel)
            }
            heroList
        }
    }

    @ViewBuilder
    private var heroList: some View {
        if !viewModel.hasScanned && viewModel.issues.isEmpty {
            Text("Scanning…")
                .font(Typography.body)
                .foregroundStyle(Palette.tertiaryLabel)
                .padding(.vertical, Spacing.s)
        } else if viewModel.recentIssues.isEmpty {
            HStack(spacing: Spacing.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.success)
                Text("No issues detected")
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            .padding(.vertical, Spacing.s)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.recentIssues.enumerated()), id: \.element.id) { idx, issue in
                    findingRow(issue)
                    if idx < viewModel.recentIssues.count - 1 {
                        Divider().foregroundStyle(Palette.separator)
                    }
                }
            }
        }
    }

    /// One finding row — icon + title + tool · savings on the right.
    /// Tight, single-line, developer-density.
    private func findingRow(_ issue: DiagnosticIssue) -> some View {
        Button {
            router.showDiagnosticsIssue(issue.id)
        } label: {
            HStack(alignment: .center, spacing: Spacing.s) {
                Image(systemName: severityIcon(issue.severity))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(severityColor(issue.severity))
                    .frame(width: 14)

                Text(issue.title)
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)

                Text("·")
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)

                Text(issue.toolID.rawValue.capitalized)
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                if let savings = issue.estimatedSavingsBytes, savings > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(savings), countStyle: .binary))
                        .font(Typography.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Actions

    private var actionsSection: some View {
        let actionable = actionableIssues
        return Group {
            if !actionable.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionEyebrow("Recommended Actions")
                        Spacer(minLength: 0)
                        Text("\(actionable.count)")
                            .font(Typography.caption2.monospacedDigit())
                            .foregroundStyle(Palette.tertiaryLabel)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(actionable.enumerated()), id: \.element.id) { idx, issue in
                            actionRow(issue)
                            if idx < actionable.count - 1 {
                                Divider().foregroundStyle(Palette.separator)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Issues where a fix is available and the savings are worth
    /// acting on. Sorted by savings descending.
    private var actionableIssues: [DiagnosticIssue] {
        viewModel.issues
            .filter { $0.fixAvailable && ($0.estimatedSavingsBytes ?? 0) > 0 }
            .sorted { ($0.estimatedSavingsBytes ?? 0) > ($1.estimatedSavingsBytes ?? 0) }
            .prefix(3)
            .map { $0 }
    }

    /// One recommended action row — terse, single-line. Tap to open
    /// the issue in Diagnostics.
    private func actionRow(_ issue: DiagnosticIssue) -> some View {
        Button {
            router.showDiagnosticsIssue(issue.id)
        } label: {
            HStack(alignment: .center, spacing: Spacing.s) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 14)

                Text("Reclaim \(formattedSavings(issue.estimatedSavingsBytes ?? 0))")
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.textPrimary)

                Text("·")
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)

                Text(issue.toolID.rawValue.capitalized)
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.tertiaryLabel)
                    .lineLimit(1)

                Spacer(minLength: Spacing.s)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.tertiaryLabel)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formattedSavings(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    // MARK: - Storage Summary

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                SectionEyebrow("Storage by Tool")
                Spacer(minLength: 0)
                Text(ByteCountFormatter.string(
                    fromByteCount: Int64(viewModel.potentialCleanupBytes),
                    countStyle: .binary
                ))
                    .font(Typography.caption2.monospacedDigit())
                    .foregroundStyle(Palette.tertiaryLabel)
            }

            if storageViewModel.storageByTool.isEmpty {
                Text(storageViewModel.isAnalyzing ? "Analyzing storage…" : "No reclaimable storage detected.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.tertiaryLabel)
                    .padding(.vertical, Spacing.s)
            } else {
                storageTable
            }
        }
    }

    private var storageTable: some View {
        let total = storageViewModel.storageByTool.reduce(UInt64(0)) { $0 + $1.bytes }
        return VStack(spacing: 0) {
            storageTableHeader
            Divider().foregroundStyle(Palette.separator)
            ForEach(Array(storageViewModel.storageByTool.prefix(6).enumerated()), id: \.element.id) { idx, bucket in
                storageTableRow(bucket: bucket, total: total)
                if idx < min(storageViewModel.storageByTool.count, 6) - 1 {
                    Divider().foregroundStyle(Palette.separator)
                }
            }
        }
    }

    private var storageTableHeader: some View {
        HStack {
            Text("Tool")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Reclaimable")
                .frame(width: 100, alignment: .trailing)
            Text("%")
                .frame(width: 44, alignment: .trailing)
        }
        .font(Typography.caption2.weight(.medium))
        .tracking(0.3)
        .foregroundStyle(Palette.tertiaryLabel)
        .padding(.vertical, Spacing.xs)
    }

    private func storageTableRow(bucket: StorageBucket, total: UInt64) -> some View {
        HStack {
            Text(bucket.label)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(bucket.formattedBytes)
                .font(Typography.subheadline.monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 100, alignment: .trailing)
            Text(percentString(bucket.bytes, total: total))
                .font(Typography.subheadline.monospacedDigit())
                .foregroundStyle(Palette.tertiaryLabel)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    private func severityIcon(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .critical: return Palette.critical
        case .warning:  return Palette.warning
        case .info:     return Palette.textSecondary
        }
    }

    private var healthStatus: ToolbarStatus.Status {
        if viewModel.criticalCount > 0 { return .critical }
        if viewModel.warningCount > 0 { return .warnings }
        return .healthy
    }

    private func percentString(_ bytes: UInt64, total: UInt64) -> String {
        guard total > 0 else { return "0%" }
        let pct = Double(bytes) / Double(total) * 100
        return String(format: "%.0f%%", pct)
    }

    private static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func lastScanRelativeString(from date: Date) -> String {
        RelativeDateTimeFormatter()
            .localizedString(for: date, relativeTo: Date())
    }
}
