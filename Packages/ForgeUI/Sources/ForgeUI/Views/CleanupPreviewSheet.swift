import SwiftUI
import ForgeCore
import ForgeDesign

/// Dry-run preview sheet for the Cleanup screen — Finder-like.
///
/// Shown when the user taps [Preview Files] on the right pane of the
/// Cleanup screen, or [Apply Fix] from Diagnostics. Displays the
/// cleanup target's candidate file paths in a native `Table` with name
/// and path columns, plus a footer with totals and action buttons.
///
/// Phase 4 is dry-run only. The "Move to Trash" button is a stub — it
/// dismisses the sheet without performing any destructive operation.
/// Actual execution is deferred to a later phase.
public struct CleanupPreviewSheet: View {
    let preview: CleanupPreview

    @Environment(\.dismiss) private var dismiss

    public init(preview: CleanupPreview) {
        self.preview = preview
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fileList
            Divider()
            footer
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    // MARK: - Header

    /// Finder-like toolbar: trash icon, target name, file count / total
    /// size summary.
    private var header: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "trash")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(preview.opportunity?.displayName ?? preview.report.target)
                    .font(Typography.headline)
                Text("\(preview.candidateCount) files · \(preview.totalFormatted) total")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Spacing.m)
        .background(.bar)
    }

    // MARK: - File list

    /// Native `Table` of every candidate path with Name and Path
    /// columns. Falls back to an empty-state placeholder when the
    /// dry-run returned no candidates.
    @ViewBuilder
    private var fileList: some View {
        if preview.report.candidatePaths.isEmpty {
            Spacer()
            Text("No files to remove.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            Table(preview.report.candidatePaths.map { FileRow(url: $0) }) {
                TableColumn("Name") { row in
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        Text(row.url.lastPathComponent)
                            .lineLimit(1)
                    }
                }
                TableColumn("Path") { row in
                    Text(row.url.path)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .width(min: 200, ideal: 320)
            }
            .frame(minHeight: 360)
        }
    }

    // MARK: - Footer

    /// Footer row — reclaimable total on the left, Cancel / Move to
    /// Trash actions on the right. The Move button is a stub for now.
    private var footer: some View {
        HStack {
            Text("Reclaimable: \(preview.totalFormatted)")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Move to Trash") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(preview.report.candidatePaths.isEmpty)
        }
        .padding(Spacing.m)
        .background(.bar)
    }

    // MARK: - Row model

    /// Identifiable wrapper around `URL` so the table can iterate the
    /// preview's `candidatePaths`. Stable per-URL identity prevents the
    /// table from rebuilding rows every render.
    private struct FileRow: Identifiable {
        let id = UUID()
        let url: URL
    }
}
