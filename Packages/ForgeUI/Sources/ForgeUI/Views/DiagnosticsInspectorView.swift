import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Inspector pane for the Diagnostics screen. Rendered in the third
/// column of `RootView` when a finding is selected. Looks up the
/// `DiagnosticIssue` by id from `DiagnosticsViewModel` and renders the
/// full description + remediation + Apply Fix button.
public struct DiagnosticsInspectorView: View {
    @EnvironmentObject private var viewModel: DiagnosticsViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let issueID: UUID

    @State private var previewIssue: DiagnosticIssue?
    @State private var preview: CleanupPreview?

    public init(issueID: UUID) {
        self.issueID = issueID
    }

    /// Look up the issue across all severity buckets.
    private var issue: DiagnosticIssue? {
        let all = viewModel.critical + viewModel.warnings + viewModel.info
        return all.first { $0.id == issueID }
    }

    public var body: some View {
        Group {
            if let issue {
                IssueDetailContent(issue: issue, onApplyFix: {
                    applyFix(for: issue)
                })
            } else {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Finding not available")
                        .font(Typography.headline)
                        .foregroundStyle(.secondary)
                    Text("It may have been resolved or removed by a re-analysis.")
                        .font(Typography.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.xl)
            }
        }
        .sheet(item: $previewIssue) { issue in
            ApplyFixSheet(issue: issue, preview: preview)
                .environmentObject(environment)
        }
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
}

// MARK: - Detail content

/// Reusable detail layout for a single `DiagnosticIssue`. Public so the
/// Diagnostics list (and any future preview surfaces) can reuse it.
public struct IssueDetailContent: View {
    let issue: DiagnosticIssue
    let onApplyFix: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                InspectorSection("Details") {
                    KeyValueRow("Severity", issue.severity.rawValue.capitalized)
                    KeyValueRow("Tool", issue.toolID.rawValue.capitalized)
                    if let savings = issue.estimatedSavingsBytes {
                        KeyValueRow("Savings", ByteCountFormatter.string(fromByteCount: Int64(savings), countStyle: .binary))
                    }
                }

                InspectorSection("Description") {
                    Text(issue.explanation)
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let remediation = issue.remediationText, !remediation.isEmpty {
                    InspectorSection("Suggested Fix") {
                        Text(remediation)
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if issue.fixAvailable {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Divider()
                        Button {
                            onApplyFix()
                        } label: {
                            Label("Apply Fix", systemImage: "wrench.and.screwdriver.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(Spacing.m)
                }
            }
        }
    }

    /// Typographic header — severity icon + title + tool name. The
    /// savings byte count, when present, renders as a quieter line
    /// below the title.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: severityIcon(issue.severity))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(severityColor(issue.severity))
                Text(issue.title)
                    .font(Typography.title3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack(spacing: Spacing.xs) {
                Text(issue.toolID.rawValue.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiaryLabel)
                if let savings = issue.estimatedSavingsBytes, savings > 0 {
                    Text("·")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.tertiaryLabel)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(savings), countStyle: .binary))
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(severityColor(issue.severity))
                }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

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
}

// MARK: - Apply Fix sheet

/// Sheet content shown when the user taps "Apply Fix".
public struct ApplyFixSheet: View {
    @EnvironmentObject private var environment: AppEnvironment
    let issue: DiagnosticIssue
    let preview: CleanupPreview?

    public var body: some View {
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
