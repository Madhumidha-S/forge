import SwiftUI
import ForgeCore
import ForgeDesign

/// Dry-run preview sheet for the Cleanup screen.
///
/// Shown when the user taps [Preview] on a row or "Preview All" at the
/// bottom of the Cleanup table. Displays exactly what the cleanup action
/// would touch — file paths, count, total reclaimable bytes — and makes
/// clear that nothing has been deleted yet.
///
/// Phase 4 is dry-run only: no destructive execution. The sheet is the
/// final gate before the user would commit to a real cleanup in a future
/// phase.
public struct CleanupPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: CleanupPreview

    public init(preview: CleanupPreview) {
        self.preview = preview
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header

            ForgeCard {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    statRow("Target", value: preview.report.target)
                    statRow("Paths", value: "\(preview.candidateCount)")
                    statRow("Reclaimable", value: preview.totalFormatted)
                    statRow("Scanned", value: preview.report.scannedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if !preview.report.candidatePaths.isEmpty {
                ForgeCard {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text("Would move to Trash")
                            .font(Typography.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                        ScrollView {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                ForEach(preview.report.candidatePaths.prefix(20), id: \.self) { path in
                                    Text(path.path)
                                        .font(Typography.caption.monospaced())
                                        .foregroundStyle(Palette.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                if preview.report.candidatePaths.count > 20 {
                                    Text("… and \(preview.report.candidatePaths.count - 20) more")
                                        .font(Typography.caption)
                                        .foregroundStyle(Palette.textTertiary)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(Spacing.xl)
        .frame(minWidth: 500, minHeight: 400)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "trash")
                    .font(Typography.title)
                    .foregroundStyle(Palette.warning)
                Text("Cleanup Preview")
                    .font(Typography.title2)
                    .foregroundStyle(Palette.textPrimary)
            }
            Text("Nothing has been deleted. This is a dry-run.")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
    }
}
