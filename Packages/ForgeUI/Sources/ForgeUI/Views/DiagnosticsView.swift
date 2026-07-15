import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Diagnostics — Xcode Issue Navigator style.
///
/// A flat list of findings where severity is communicated only by
/// icon color. No section headers, no card chrome, no pills. Each row
/// reads as one line of type: severity icon, title, tool as secondary
/// text, optional savings on the right. Compact, dense, scannable.
///
/// Toolbar:
///   ● 1 critical · 2m ago     [Critical ▾]             ⟳
public struct DiagnosticsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var viewModel: DiagnosticsViewModel
    @EnvironmentObject private var router: AppRouter

    @State private var searchQuery: String = ""
    @State private var severityFilter: SeverityFilter = .all
    @State private var previewIssue: DiagnosticIssue?
    @State private var preview: CleanupPreview?

    public init() {}

    public var body: some View {
        Group {
            if hasAnalyzedAndFoundNothing {
                EmptyState(
                    systemImage: "checkmark.seal",
                    title: "No diagnostics found",
                    description: "Your environment looks healthy."
                ) {
                    Button("Run Full Scan") {
                        Task { await viewModel.analyze() }
                    }
                    .controlSize(.large)
                }
            } else if viewModel.isAnalyzing && allIssues.isEmpty {
                loadingPlaceholder
            } else if filteredIssues.isEmpty {
                filterEmptyPlaceholder
            } else {
                issueList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Diagnostics")
        .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search findings")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarStatus(
                    status: viewModel.critical.count > 0 ? .critical
                           : viewModel.warnings.count > 0 ? .warnings
                           : .healthy,
                    lastScanRelative: viewModel.lastAnalyzedAt.flatMap(Self.relativeString(from:))
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                severityFilterMenu

                Divider().frame(height: 16)

                Button {
                    Task { await viewModel.analyze() }
                } label: {
                    Label("Re-analyze", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isAnalyzing)
                .help("Run diagnostics again")
            }
        }
        .task {
            if viewModel.critical.isEmpty && viewModel.warnings.isEmpty && viewModel.info.isEmpty {
                await viewModel.analyze()
            }
        }
        .sheet(item: $previewIssue) { issue in
            ApplyFixSheet(issue: issue, preview: preview)
                .environmentObject(router)
        }
    }

    // MARK: - Derived data

    var allIssues: [DiagnosticIssue] {
        viewModel.critical + viewModel.warnings + viewModel.info
    }

    private var hasAnalyzedAndFoundNothing: Bool {
        !viewModel.isAnalyzing
            && viewModel.lastAnalyzedAt != nil
            && viewModel.critical.isEmpty
            && viewModel.warnings.isEmpty
            && viewModel.info.isEmpty
    }

    private var filteredIssues: [DiagnosticIssue] {
        var issues = allIssues
        if severityFilter != .all {
            issues = issues.filter { $0.severity == severityFilter.severity }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            issues = issues.filter { issue in
                issue.title.lowercased().contains(q)
                    || issue.toolID.rawValue.lowercased().contains(q)
                    || issue.explanation.lowercased().contains(q)
            }
        }
        return issues
    }

    // MARK: - List

    /// Flat list. No sections, no headers — just rows. Xcode Navigator.
    private var issueList: some View {
        List(selection: selectedIssueIDBinding) {
            ForEach(filteredIssues) { issue in
                IssueRow(issue: issue)
                    .tag(issue.id)
            }
        }
        .listStyle(.sidebar)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
            Text("Analyzing…")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filterEmptyPlaceholder: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title)
                .foregroundStyle(Palette.textSecondary)
            Text("No findings match your filter")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Severity filter menu

    /// Popup menu replacing the segmented picker for severity filter —
    /// matches Xcode's filter behavior. Shows the current filter as
    /// the menu label.
    private var severityFilterMenu: some View {
        Menu {
            ForEach(SeverityFilter.allCases, id: \.self) { filter in
                Button {
                    severityFilter = filter
                } label: {
                    if severityFilter == filter {
                        Label(filter.label, systemImage: "checkmark")
                    } else {
                        Text(filter.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(severityFilter.label)
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

    private var selectedIssueIDBinding: Binding<UUID?> {
        Binding(
            get: { router.selectedIssueID },
            set: { router.selectIssue($0) }
        )
    }

    // MARK: - Apply Fix

    private func applyFix(for issue: DiagnosticIssue) {
        previewIssue = issue
        Task { await loadPreview(for: issue) }
    }

    private func loadPreview(for issue: DiagnosticIssue) async {
        let actions = await environment.cleanupServiceRegistry.availableActions()
        guard let action = Self.firstAction(matching: issue.toolID, in: actions) else {
            preview = nil
            return
        }
        do {
            preview = CleanupPreview(
                opportunity: nil,
                report: try await action.dryRun()
            )
        } catch {
            preview = nil
        }
    }

    static func firstAction(
        matching toolID: ToolID,
        in actions: [any CleanupActionProtocol]
    ) -> (any CleanupActionProtocol)? {
        let haystack = toolID.rawValue.lowercased()
        return actions.first { action in
            let target = "\(action.id) \(action.displayName)".lowercased()
            return target.contains(haystack)
        }
    }

    static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Issue row (Xcode Navigator density)

/// One row in the issue navigator. Tight vertical padding, small
/// `subheadline` font for both title and tool, monospaced savings on
/// the right. Severity icon's color is the only severity signal.
private struct IssueRow: View {
    let issue: DiagnosticIssue

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Image(systemName: severityIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(severityColor)
                .frame(width: 16)

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
    }

    private var severityIcon: String {
        switch issue.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .critical: return Palette.critical
        case .warning:  return Palette.warning
        case .info:     return Palette.textSecondary
        }
    }
}

// MARK: - Severity filter

enum SeverityFilter: Hashable, CaseIterable {
    case all
    case critical
    case warning
    case info

    var label: String {
        switch self {
        case .all:      return "All"
        case .critical: return "Critical"
        case .warning:  return "Warnings"
        case .info:     return "Info"
        }
    }

    var severity: DiagnosticSeverity? {
        switch self {
        case .all:      return nil
        case .critical: return .critical
        case .warning:  return .warning
        case .info:     return .info
        }
    }
}
