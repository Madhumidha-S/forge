import SwiftUI
import ForgeCore
import ForgeDesign

/// Cleanup — focused action page.
///
/// Lists reclaimable opportunities as task rows the user can act on.
/// No hero, no dashboard tiles — just a quiet header summarizing the
/// total reclaimable space and a list of recommendations.
///
/// Layout:
///   41.7 GB reclaimable
///   ───────────────────────────────────────────
///   ●  DerivedData                            18.4 GB
///      Xcode
///   ───────────────────────────────────────────
///   ●  Docker images                          12.0 GB
///      Docker
public struct CleanupView: View {
    @EnvironmentObject private var viewModel: CleanupViewModel
    @EnvironmentObject private var router: AppRouter

    public init() {}

    public var body: some View {
        Group {
            if hasScannedAndFoundNothing {
                cleanupEmptyState
            } else if isLoadingWithNothingToShow {
                loadingPlaceholder
            } else if viewModel.opportunities.isEmpty {
                cleanupEmptyState
            } else {
                opportunitiesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Cleanup")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarStatus(
                    status: viewModel.isLoading ? .idle
                         : viewModel.opportunities.contains(where: { $0.estimatedSavingsBytes > 10_000_000_000 }) ? .critical
                         : !viewModel.opportunities.isEmpty ? .warnings
                         : .healthy,
                    lastScanRelative: nil
                )
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .keyboardShortcut("r", modifiers: .command)
                .help("Scan for cleanup opportunities")
            }
        }
        .task {
            if viewModel.opportunities.isEmpty {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Derived state

    private var hasScannedAndFoundNothing: Bool {
        !viewModel.isLoading
            && viewModel.opportunities.isEmpty
            && viewModel.lastError == nil
    }

    private var isLoadingWithNothingToShow: Bool {
        viewModel.isLoading && viewModel.opportunities.isEmpty
    }

    private var totalReclaimable: UInt64 {
        viewModel.opportunities.reduce(UInt64(0)) { $0 + $1.estimatedSavingsBytes }
    }

    // MARK: - List

    /// Focused action layout: a small total header, then the
    /// opportunity list. No card chrome, no section headers.
    private var opportunitiesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s) {
                header
                list
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: 880, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    /// Quiet header — total reclaimable in larger type, secondary line
    /// counts how many opportunities exist.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(ByteCountFormatter.string(
                fromByteCount: Int64(totalReclaimable),
                countStyle: .binary
            ))
                .font(Typography.monospacedDigitLarge)
                .foregroundStyle(Palette.textPrimary)
            Text("reclaimable")
                .font(Typography.subheadline)
                .foregroundStyle(Palette.secondaryLabel)
            Spacer(minLength: 0)
            Text("\(viewModel.opportunities.count) opportunit\(viewModel.opportunities.count == 1 ? "y" : "ies")")
                .font(Typography.subheadline)
                .foregroundStyle(Palette.tertiaryLabel)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.opportunities.enumerated()), id: \.element.id) { idx, opp in
                OpportunityRow(opportunity: opp)
                    .tag(opp.id as String?)
                if idx < viewModel.opportunities.count - 1 {
                    Divider().foregroundStyle(Palette.separator)
                }
            }
        }
    }

    // MARK: - Empty state

    /// Premium empty state — light sparkles icon, premium typography,
    /// Apple proportions. Avoids the generic "Nothing to show" feel.
    private var cleanupEmptyState: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Palette.secondaryLabel)
            VStack(spacing: Spacing.xs) {
                Text("All clean")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text("No reclaimable storage detected. Run a scan if you think this is wrong.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Re-scan") {
                Task { await viewModel.refresh() }
            }
            .controlSize(.regular)
            .disabled(viewModel.isLoading)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
            Text("Scanning for cleanup opportunities…")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Selection

    private var selectedOpportunityIDBinding: Binding<String?> {
        Binding(
            get: { router.selectedOpportunityID },
            set: { router.selectOpportunity($0) }
        )
    }
}

// MARK: - Opportunity row

/// One action row. Layout: small accent dot · title · tool as
/// secondary text · reclaimable bytes on the right. Tight vertical
/// padding. Selection is implied by the row's tap target — no chevron
/// (Reminders / Things pattern).
private struct OpportunityRow: View {
    let opportunity: CleanupOpportunity

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            StatusDot(Palette.accent, size: 7)

            Text(opportunity.displayName)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)

            Text("·")
                .font(Typography.subheadline)
                .foregroundStyle(Palette.tertiaryLabel)

            Text(opportunity.toolID.rawValue.capitalized)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.tertiaryLabel)
                .lineLimit(1)

            Spacer(minLength: Spacing.s)

            Text(opportunity.reclaimableFormatted)
                .font(Typography.subheadline.monospacedDigit())
                .foregroundStyle(Palette.secondaryLabel)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
