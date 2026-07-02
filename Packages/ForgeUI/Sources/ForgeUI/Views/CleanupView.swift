import SwiftUI
import ForgeCore
import ForgeDesign

/// Cleanup screen — table of cleanup opportunities with dry-run preview.
///
/// Phase 4 ships dry-run only. Each row shows a cleanup action with the
/// diagnostic engine's estimate of reclaimable bytes, plus a [Preview]
/// button that runs the action's `dryRun()` and shows exactly what would
/// be touched (no destructive execution).
///
/// The screen coordinates with `CleanupViewModel`. On appear and on the
/// toolbar Refresh action, `refresh()` reads the cleanup registry and
/// re-runs the diagnostics engine.
public struct CleanupView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: CleanupViewModel
    @State private var showingPreview: CleanupPreview?

    public init(viewModel: CleanupViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: CleanupViewModel.preview())
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                SectionHeader(
                    "Cleanup",
                    subtitle: subtitleText
                )

                if viewModel.isLoading && viewModel.opportunities.isEmpty {
                    analyzingPlaceholder
                } else if viewModel.opportunities.isEmpty {
                    emptyPlaceholder
                } else {
                    opportunitiesTable
                }

                if hasPreviews {
                    previewAllButton
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.opportunities.isEmpty {
                await viewModel.refresh()
            }
        }
        .sheet(item: $showingPreview) { preview in
            CleanupPreviewSheet(preview: preview)
        }
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        let totalReclaimable = viewModel.opportunities.reduce(UInt64(0)) { $0 + $1.estimatedSavingsBytes }
        let count = viewModel.opportunities.count
        let totalFormatted = ByteCountFormatter.string(fromByteCount: Int64(totalReclaimable), countStyle: .binary)
        return "\(count) cleanup opportunities, \(totalFormatted) potential reclaim"
    }

    private var hasPreviews: Bool {
        viewModel.opportunities.contains { $0.action != nil }
    }

    // MARK: - Table

    private var opportunitiesTable: some View {
        ForgeCard(padding: 0) {
            VStack(spacing: 0) {
                tableHeader
                ForEach(Array(viewModel.opportunities.enumerated()), id: \.element.id) { index, opp in
                    if index > 0 {
                        Divider()
                    }
                    opportunityRow(opp)
                }
            }
        }
    }

    private var tableHeader: some View {
        HStack {
            Text("Tool")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Current Size")
                .frame(width: 120, alignment: .trailing)
            Text("Reclaimable")
                .frame(width: 120, alignment: .trailing)
            Text("Action")
                .frame(width: 120, alignment: .trailing)
        }
        .font(Typography.caption)
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Palette.surface.opacity(0.5))
    }

    private func opportunityRow(_ opp: CleanupOpportunity) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(opp.displayName)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text(opp.toolID.rawValue.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("—")
                .font(Typography.body.monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 120, alignment: .trailing)

            Text(opp.reclaimableFormatted)
                .font(Typography.body.monospacedDigit())
                .foregroundStyle(opp.estimatedSavingsBytes > 0 ? Palette.warning : Palette.textSecondary)
                .frame(width: 120, alignment: .trailing)

            Button("Preview") {
                Task {
                    await viewModel.preview(opp)
                    showingPreview = viewModel.preview
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(opp.action == nil)
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Preview All

    private var previewAllButton: some View {
        HStack {
            Spacer()
            Button {
                Task {
                    await viewModel.previewAll()
                    showingPreview = viewModel.preview
                }
            } label: {
                Label("Preview All", systemImage: "eye.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Placeholders

    private var analyzingPlaceholder: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Loading cleanup opportunities…")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                ProgressView()
            }
        }
    }

    private var emptyPlaceholder: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("No cleanup actions available.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("Install cleanup actions or check that Forge can see your dev tools.")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
