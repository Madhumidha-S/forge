import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Inspector pane for the Cleanup screen. Rendered in the third
/// column of `RootView` when an opportunity is selected.
public struct CleanupInspectorView: View {
    @EnvironmentObject private var viewModel: CleanupViewModel
    let opportunityID: String

    public init(opportunityID: String) {
        self.opportunityID = opportunityID
    }

    private var opportunity: CleanupOpportunity? {
        viewModel.opportunities.first { $0.id == opportunityID }
    }

    public var body: some View {
        Group {
            if let opportunity {
                OpportunityDetailContent(opportunity: opportunity, onPreview: {
                    Task { await viewModel.preview(opportunity) }
                })
                .sheet(item: Binding(
                    get: { viewModel.preview.map { PreviewSheetItem(preview: $0) } },
                    set: { newValue in
                        if newValue == nil { viewModel.dismissPreview() }
                    }
                )) { item in
                    CleanupPreviewSheet(preview: item.preview)
                }
            } else {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Recommendation not available")
                        .font(Typography.headline)
                        .foregroundStyle(.secondary)
                    Text("It may have been resolved or removed by a re-scan.")
                        .font(Typography.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(Spacing.xl)
            }
        }
    }

    /// Identifiable wrapper around `CleanupPreview` that drives
    /// `.sheet(item:)`.
    private struct PreviewSheetItem: Identifiable {
        let id = UUID()
        let preview: CleanupPreview
    }
}

// MARK: - Detail content

/// Reusable detail layout for a single `CleanupOpportunity`.
public struct OpportunityDetailContent: View {
    let opportunity: CleanupOpportunity
    let onPreview: () -> Void

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                InspectorSection("Details") {
                    KeyValueRow("Risk", "Low")
                    KeyValueRow("Reclaimable", opportunity.reclaimableFormatted)
                    KeyValueRow("Tool", opportunity.toolID.rawValue.capitalized)
                    if let action = opportunity.action {
                        KeyValueRow("Action ID", action.id)
                    }
                }

                if let action = opportunity.action {
                    InspectorSection("Description") {
                        Text("Removes reclaimable files via \(action.displayName). Files are moved to Trash, not deleted.")
                            .font(Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if opportunity.action != nil {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Divider()
                        Button {
                            onPreview()
                        } label: {
                            Label("Preview Files", systemImage: "eye")
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

    /// Typographic header — title + tool name + reclaimable bytes. No
    /// big colored icon; the accent dot lives in the row the user
    /// clicked to get here.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(opportunity.displayName)
                .font(Typography.title3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.xs) {
                Text(opportunity.toolID.rawValue.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiaryLabel)
                Text("·")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiaryLabel)
                Text(opportunity.reclaimableFormatted)
                    .font(Typography.caption.monospacedDigit())
                    .foregroundStyle(Palette.success)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
