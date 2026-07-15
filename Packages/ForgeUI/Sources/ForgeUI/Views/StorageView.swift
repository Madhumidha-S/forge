import SwiftUI
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

/// Storage — Disk Utility style.
///
/// A document-style page that reads like a list of volumes, not a
/// chart. Each tool gets a row with a thin horizontal usage bar
/// showing its share of total reclaimable space. No Swift Charts, no
/// boxed widgets, no analytics styling — just typography and a few
/// hairline dividers.
///
/// Layout:
///   41.7 GB reclaimable · last analyzed 2m ago
///   ───────────────────────────────────────────
///   ● Caches 12 GB   ● Runtimes 8 GB   ● Models 6 GB
///   ───────────────────────────────────────────
///   Storage by Tool
///   ───────────────────────────────────────────
///   🛠  Xcode          ████████████     18.4 GB   44%
///      Docker          ████████         12.0 GB   29%
///      Ollama          █████             6.8 GB   16%
///      ...
public struct StorageView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var viewModel: StorageViewModel

    public init() {}

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Storage")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ToolbarStatus(
                        status: viewModel.isAnalyzing ? .idle
                             : viewModel.totalReclaimableBytes > 50_000_000_000 ? .critical
                             : viewModel.totalReclaimableBytes > 0 ? .warnings
                             : .healthy,
                        lastScanRelative: viewModel.lastAnalyzedAt.map(Self.relativeString(from:))
                    )
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.analyze() }
                    } label: {
                        Label("Analyze", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isAnalyzing)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Re-analyze storage")
                }
            }
            .task {
                if viewModel.totalReclaimableBytes == 0 {
                    await viewModel.analyze()
                }
            }
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if viewModel.isAnalyzing && viewModel.storageByTool.isEmpty {
            analyzingView
        } else if !viewModel.isAnalyzing
                    && viewModel.storageByTool.isEmpty
                    && viewModel.lastAnalyzedAt == nil {
            neverScannedView
        } else if !viewModel.isAnalyzing
                    && viewModel.storageByTool.isEmpty
                    && viewModel.lastAnalyzedAt != nil {
            emptyState
        } else {
            populatedView
        }
    }

    private var analyzingView: some View {
        VStack(spacing: Spacing.m) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing storage…")
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var neverScannedView: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "internaldrive")
                .font(.system(size: 36))
                .foregroundStyle(Palette.tertiaryLabel)
            Text("Storage analysis not yet performed.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Button("Run Analysis") { Task { await viewModel.analyze() } }
                .controlSize(.regular)
                .disabled(viewModel.isAnalyzing)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private var emptyState: some View {
        EmptyState(
            systemImage: "internaldrive",
            title: "No reclaimable storage detected",
            description: "Run a scan to see what's using space."
        ) {
            Button("Scan Now") {
                Task { await viewModel.analyze() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    private var populatedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                categoryLegend
                storageList
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxl)
            .frame(maxWidth: 880, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Header

    /// Page header — reclaimable bytes + relative last-analyzed time.
    /// No big title; the window title bar shows "Storage".
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(ByteCountFormatter.string(
                    fromByteCount: Int64(viewModel.totalReclaimableBytes),
                    countStyle: .binary
                ))
                    .font(Typography.monospacedDigitLarge)
                    .foregroundStyle(Palette.textPrimary)
                Text("reclaimable")
                    .font(Typography.subheadline)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            if let last = viewModel.lastAnalyzedAt {
                Text("Last analyzed \(last.formatted(.relative(presentation: .named)))")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiaryLabel)
            }
        }
    }

    // MARK: - Category legend

    /// Inline strip of category dots with labels and byte totals.
    @ViewBuilder
    private var categoryLegend: some View {
        if !viewModel.storageByCategory.isEmpty {
            HStack(spacing: Spacing.l) {
                ForEach(viewModel.storageByCategory) { bucket in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor(bucket.id))
                            .frame(width: 7, height: 7)
                        Text(bucket.label)
                            .font(Typography.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                        Text(bucket.formattedBytes)
                            .font(Typography.subheadline.monospacedDigit())
                            .foregroundStyle(Palette.tertiaryLabel)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Storage list (Disk Utility style)

    /// The list of tools with horizontal usage bars. This replaces
    /// what was previously a Swift Charts bar chart. Each row:
    /// tool icon · name · thin horizontal bar · reclaimable · %.
    private var storageList: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionEyebrow("Storage by Tool")

            VStack(spacing: 0) {
                let total = viewModel.storageByTool.reduce(UInt64(0)) { $0 + $1.bytes }
                ForEach(Array(viewModel.storageByTool.enumerated()), id: \.element.id) { idx, bucket in
                    storageRow(bucket: bucket, total: total)
                    if idx < viewModel.storageByTool.count - 1 {
                        Divider().foregroundStyle(Palette.separator)
                    }
                }
            }
        }
    }

    /// One row: tool icon · name · usage bar · reclaimable · %.
    /// The bar fills proportional to bytes / total, drawn as a thin
    /// rounded rectangle — no Swift Charts.
    private func storageRow(bucket: StorageBucket, total: UInt64) -> some View {
        let fraction = total > 0 ? Double(bucket.bytes) / Double(total) : 0
        return HStack(spacing: Spacing.m) {
            Image(systemName: toolSymbol(for: bucket.id))
                .font(.system(size: 13))
                .foregroundStyle(Palette.secondaryLabel)
                .frame(width: 18)

            Text(bucket.label)
                .font(Typography.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            UsageBar(fraction: fraction)
                .frame(height: 6)

            Text(bucket.formattedBytes)
                .font(Typography.subheadline.monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 80, alignment: .trailing)

            Text(percentString(bucket.bytes, total: total))
                .font(Typography.subheadline.monospacedDigit())
                .foregroundStyle(Palette.tertiaryLabel)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func percentString(_ bytes: UInt64, total: UInt64) -> String {
        guard total > 0 else { return "0%" }
        let pct = Double(bytes) / Double(total) * 100
        return String(format: "%.0f%%", pct)
    }

    /// Tool icon symbol — mirrors what `ToolsView` uses so Storage
    /// rows match the Tools table visually.
    private func toolSymbol(for toolID: String) -> String {
        switch toolID.lowercased() {
        case "docker":      return "shippingbox.fill"
        case "flutter":     return "bird"
        case "git":         return "arrow.triangle.branch"
        case "homebrew":    return "mug.fill"
        case "java":        return "cup.and.saucer.fill"
        case "node":        return "n.circle.fill"
        case "ollama":      return "cpu.fill"
        case "python":      return "chevron.left.forwardslash.chevron.right"
        default:            return "wrench.and.screwdriver.fill"
        }
    }

    /// Muted categorical palette for the legend dots.
    private func categoryColor(_ categoryId: String) -> Color {
        switch categoryId {
        case StorageCategory.runtimes.rawValue:        return Color.blue.opacity(0.85)
        case StorageCategory.buildArtifacts.rawValue: return Color.orange.opacity(0.85)
        case StorageCategory.models.rawValue:         return Color.purple.opacity(0.85)
        case StorageCategory.caches.rawValue:         return Color.teal.opacity(0.85)
        case StorageCategory.cliTools.rawValue:       return Color.pink.opacity(0.85)
        default:                                      return Palette.accent.opacity(0.85)
        }
    }
}

// MARK: - UsageBar

/// Thin horizontal usage bar — the visual primitive that replaces
/// Swift Charts on this page. Pure geometry, no chart library.
///
/// Drawn as a track (very faint background) with a fill bar at the
/// given fraction (0.0 to 1.0) of the available width. The fill is
/// the system accent at reduced opacity so it reads as a quiet data
/// indicator, not a chart element.
struct UsageBar: View {
    let fraction: Double
    var color: Color = Palette.accent.opacity(0.78)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.separator.opacity(0.6))
                Capsule()
                    .fill(color)
                    .frame(width: max(2, geo.size.width * max(0, min(fraction, 1))))
            }
        }
    }
}
