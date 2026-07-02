import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Overview screen — environment health at a glance.
///
/// Layout matches the architecture doc's wireframe:
/// - Health Score (large number + ring)
/// - Healthy / Warnings / Critical counts with colored dots
/// - Potential Cleanup (total reclaimable + "Review Cleanup Plan" button)
/// - Recently Detected Issues (top 3 by severity, then by savings desc)
///
/// Uses `OverviewViewModel` to coordinate with the diagnostics engine.
/// On first appear and on `Refresh` toolbar action, calls
/// `vm.analyze()` which runs `DiagnosticsEngine.analyze()` and refreshes
/// the published `issues` array.
public struct OverviewView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: OverviewViewModel

    public init(viewModel: OverviewViewModel? = nil) {
        // The real ViewModel is created from `AppEnvironment` via `.onAppear`
        // because @EnvironmentObject isn't available at init time. The
        // optional parameter exists for previews and tests.
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: OverviewViewModel.preview())
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                SectionHeader(
                    "Overview",
                    subtitle: "Environment health at a glance"
                )

                healthScoreCard
                countsCard
                cleanupCard
                recentIssuesCard
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
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isAnalyzing)
            }
        }
        .task {
            // Initial analyze on first appear.
            if viewModel.issues.isEmpty {
                await viewModel.analyze()
            }
        }
    }

    // MARK: - Cards

    private var healthScoreCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Health Score")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text("\(viewModel.healthScore)")
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(healthScoreColor)
                    Text("%")
                        .font(Typography.title)
                        .foregroundStyle(Palette.textSecondary)
                }
                if let last = viewModel.lastAnalyzedAt {
                    Text("Last analyzed \(last, style: .relative) ago")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    private var countsCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Tool Health")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: Spacing.xl) {
                    countPill("Healthy", value: viewModel.healthyCount, color: Palette.success)
                    countPill("Warnings", value: viewModel.warningCount, color: Palette.warning)
                    countPill("Critical", value: viewModel.criticalCount, color: Palette.critical)
                }
            }
        }
    }

    private var cleanupCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Potential Cleanup")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.potentialCleanupBytes), countStyle: .binary))
                    .font(Typography.title)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                Text("\(viewModel.issues.filter { $0.estimatedSavingsBytes != nil }.count) items reclaimable")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                Button("Review Cleanup Plan") {
                    // Phase 4J wires this to the CleanupView preview sheet.
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.issues.isEmpty)
            }
        }
    }

    private var recentIssuesCard: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Recently Detected")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)

                if viewModel.recentIssues.isEmpty {
                    Text(viewModel.isAnalyzing ? "Analyzing…" : "No issues detected.")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    ForEach(viewModel.recentIssues) { issue in
                        issueRow(issue)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var healthScoreColor: Color {
        let score = viewModel.healthScore
        if score >= 80 { return Palette.success }
        if score >= 50 { return Palette.warning }
        return Palette.critical
    }

    private func countPill(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: Spacing.s) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("\(value)")
                .font(Typography.title3)
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func issueRow(_ issue: DiagnosticIssue) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: severityIcon(issue.severity))
                .foregroundStyle(severityColor(issue.severity))
                .font(.body)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(issue.title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                if let savings = issue.estimatedSavingsBytes, savings > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(savings), countStyle: .binary))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
        .padding(.vertical, Spacing.xxs)
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
