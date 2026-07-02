import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Diagnostics screen — issues grouped by severity.
///
/// Three sections in severity order: Critical (red), Warnings (amber),
/// Information (gray). Each section is collapsible. Each issue card shows:
/// - title and tool name
/// - explanation
/// - estimated savings (when known)
/// - remediation button (runs the issue's remediation text, or opens the
///   Cleanup preview sheet for cleanup-related issues in a later phase)
///
/// The screen coordinates with `DiagnosticsEngine` via
/// `DiagnosticsViewModel`. The "Analyze" toolbar button and the
/// initial `.task` run the engine.
public struct DiagnosticsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: DiagnosticsViewModel
    @State private var previewIssue: DiagnosticIssue?
    @State private var preview: CleanupPreview?

    public init(viewModel: DiagnosticsViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: DiagnosticsViewModel.preview())
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                SectionHeader(
                    "Diagnostics",
                    subtitle: subtitleText
                )

                if viewModel.isAnalyzing && viewModel.critical.isEmpty && viewModel.warnings.isEmpty && viewModel.info.isEmpty {
                    analyzingPlaceholder
                } else if viewModel.critical.isEmpty && viewModel.warnings.isEmpty && viewModel.info.isEmpty {
                    emptyPlaceholder
                } else {
                    severitySection("Critical", issues: viewModel.critical, color: Palette.critical, icon: "exclamationmark.octagon.fill")
                    severitySection("Warnings", issues: viewModel.warnings, color: Palette.warning, icon: "exclamationmark.triangle.fill")
                    severitySection("Information", issues: viewModel.info, color: Palette.textSecondary, icon: "info.circle.fill")
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.analyze() }
                } label: {
                    Label("Analyze", systemImage: "stethoscope")
                }
                .disabled(viewModel.isAnalyzing)
            }
        }
        .task {
            if viewModel.critical.isEmpty && viewModel.warnings.isEmpty && viewModel.info.isEmpty {
                await viewModel.analyze()
            }
        }
        .sheet(item: $previewIssue) { issue in
            // "Apply Fix" on an IssueCard sets `previewIssue` and kicks off
            // a dry-run inline. By the time the sheet opens, `preview`
            // is populated and ApplyFixSheet shows the real report
            // instead of the loading spinner.
            ApplyFixSheet(issue: issue, preview: preview)
                .environmentObject(environment)
        }
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        if let last = viewModel.lastAnalyzedAt {
            let count = viewModel.critical.count + viewModel.warnings.count + viewModel.info.count
            return "\(count) issues found, last analyzed \(last.formatted(.relative(presentation: .named))) ago"
        }
        return "Issues grouped by severity"
    }

    // MARK: - Sections

    @ViewBuilder
    private func severitySection(
        _ title: String,
        issues: [DiagnosticIssue],
        color: Color,
        icon: String
    ) -> some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(Typography.headline)
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(issues.count)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xxs)
                        .background(Capsule().fill(color.opacity(0.15)))
                }
                ForEach(issues) { issue in
                    IssueCard(issue: issue) {
                        previewIssue = issue
                        Task { await loadPreview(for: issue) }
                    }
                }
            }
        }
    }

    private var analyzingPlaceholder: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Analyzing…")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                ProgressView()
            }
        }
    }

    private var emptyPlaceholder: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("No issues detected.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("Your development environment looks clean. Run Analyze to check again.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

// MARK: - Issue card

private struct IssueCard: View {
    let issue: DiagnosticIssue
    let onApplyFix: () -> Void

    var body: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    Image(systemName: severityIcon)
                        .foregroundStyle(severityColor)
                        .font(Typography.title3)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(issue.title)
                            .font(Typography.headline)
                            .foregroundStyle(Palette.textPrimary)
                        Text(issue.toolID.rawValue.capitalized)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer()
                    if let savings = issue.estimatedSavingsBytes, savings > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(savings), countStyle: .binary))
                            .font(Typography.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(severityColor)
                    }
                }

                Text(issue.explanation)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let remediation = issue.remediationText {
                    Text(remediation)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.xxs)
                }

                if issue.fixAvailable {
                    HStack {
                        Spacer()
                        Button("Apply Fix") {
                            // Defer the apply-action to the parent
                            // DiagnosticsView — IssueCard is a private
                            // struct that can't access the parent's
                            // @State properties directly. The closure
                            // captures the issue + the parent's method.
                            onApplyFix()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
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

// MARK: - Apply Fix sheet

/// Sheet content shown when the user taps "Apply Fix" on an issue card.
/// Looks up the cleanup action for the issue's tool, runs a dry-run,
/// and shows the same `CleanupPreviewSheet` the Cleanup screen uses.
private struct ApplyFixSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    let issue: DiagnosticIssue
    let preview: CleanupPreview?

    var body: some View {
        if let preview {
            CleanupPreviewSheet(preview: preview)
        } else {
            VStack(spacing: Spacing.l) {
                ProgressView()
                Text("Scanning \(issue.toolID.rawValue.capitalized)…")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}

// MARK: - Preview loading (DiagnosticsView extension)

extension DiagnosticsView {
    /// Looks up the cleanup action for the given issue's tool and runs
    /// a dry-run. The result is stored in `preview` state so the sheet
    /// picks it up on its next render.
    func loadPreview(for issue: DiagnosticIssue) async {
        let actions = await environment.cleanupServiceRegistry.availableActions()
        guard let action = Self.firstAction(matching: issue.toolID, in: actions) else {
            preview = nil
            return
        }
        do {
            let report = try await action.dryRun()
            preview = CleanupPreview(
                opportunity: nil,
                report: report
            )
        } catch {
            preview = nil
        }
    }

    /// Best-effort lookup of a cleanup action whose display target matches
    /// the given tool ID. Returns the first hit; the cleanup registry
    /// typically has one action per tool.
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
}
