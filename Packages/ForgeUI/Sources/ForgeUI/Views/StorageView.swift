import SwiftUI
import Charts
import Foundation
import ForgeCore
import ForgeDiagnostics
import ForgeDesign

// MARK: - ByteCountFormatStyle
//
// SwiftUI's `AxisMarks(format:)` requires a `FormatStyle` whose
// `FormatInput == Plottable` and `FormatOutput == String`. Foundation's
// `ByteCountFormatter` predates the FormatStyle system and doesn't conform
// to that protocol. This thin wrapper bridges the two so we can keep
// byte-count labels on the chart axes.
struct ByteCountFormatStyle: FormatStyle {
    typealias FormatInput = Int64
    typealias FormatOutput = String

    func format(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
    }

    /// Static factory so call sites read `AxisMarks(format: .binaryBytes)`
    /// rather than `AxisMarks(format: ByteCountFormatStyle())`.
    static var binaryBytes: ByteCountFormatStyle { .init() }
}

/// Storage screen — three Swift Charts visualizations backed by
/// `StorageViewModel`:
///
/// - BarMark chart of storage by tool (sorted desc)
/// - BarMark chart of storage by category (Runtimes / Build Artifacts /
///   Models / Caches / CLI Tools, sorted desc)
/// - LineMark chart of reclaimable-storage trend over the last 20 analyses
/// - "Total reclaimable" callout at the top
///
/// Charts use `Charts.Chart { ... }` (Swift Charts, macOS 13+).
public struct StorageView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var viewModel: StorageViewModel

    public init(viewModel: StorageViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: StorageViewModel.preview())
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                SectionHeader(
                    "Storage",
                    subtitle: "Storage by tool and category"
                )

                reclaimableCallout
                byToolChart
                byCategoryChart
                trendChart
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
                    Label("Analyze", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isAnalyzing)
            }
        }
        .task {
            if viewModel.totalReclaimableBytes == 0 {
                await viewModel.analyze()
            }
        }
    }

    // MARK: - Reclaimable callout

    private var reclaimableCallout: some View {
        ForgeCard {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Reclaimable")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textSecondary)
                Text(ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalReclaimableBytes), countStyle: .binary))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                Text("\(viewModel.storageByTool.count) tools contributing")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - By tool chart

    @ViewBuilder
    private var byToolChart: some View {
        if !viewModel.storageByTool.isEmpty {
            ForgeCard {
                chartSection(title: "Storage by Tool", subtitle: "Reclaimable bytes per tool") {
                    Chart(viewModel.storageByTool) { bucket in
                        BarMark(
                            x: .value("Tool", bucket.label),
                            y: .value("Bytes", Int64(bucket.bytes))
                        )
                        .foregroundStyle(Palette.accent)
                    }
                    .chartYAxis {
                        AxisMarks(format: ByteCountFormatStyle())
                    }
                    .frame(height: 240)
                }
            }
        }
    }

    // MARK: - By category chart

    @ViewBuilder
    private var byCategoryChart: some View {
        if !viewModel.storageByCategory.isEmpty {
            ForgeCard {
                chartSection(title: "Storage by Category", subtitle: "Reclaimable bytes per category") {
                    Chart(viewModel.storageByCategory) { bucket in
                        BarMark(
                            x: .value("Category", bucket.label),
                            y: .value("Bytes", Int64(bucket.bytes))
                        )
                        .foregroundStyle(byCategoryColor(bucket.id))
                    }
                    .chartYAxis {
                        AxisMarks(format: ByteCountFormatStyle())
                    }
                    .frame(height: 240)
                }
            }
        }
    }

    // MARK: - Trend chart

    @ViewBuilder
    private var trendChart: some View {
        if viewModel.reclaimableTrend.count >= 2 {
            ForgeCard {
                chartSection(title: "Reclaimable Trend", subtitle: "Total reclaimable across recent analyses") {
                    Chart(viewModel.reclaimableTrend) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Bytes", Int64(point.bytes))
                        )
                        .foregroundStyle(Palette.accent)
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Bytes", Int64(point.bytes))
                        )
                        .foregroundStyle(Palette.accent)
                        .symbolSize(40)
                    }
                    .chartYAxis {
                        AxisMarks(format: ByteCountFormatStyle())
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func chartSection<Content: View>(
        title: String,
        subtitle: String,
        content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            content()
        }
    }

    /// Color palette for the by-category chart. Mirrors the SwiftUI
    /// categorical palette so categories are visually distinct.
    private func byCategoryColor(_ categoryId: String) -> Color {
        switch categoryId {
        case StorageCategory.runtimes.rawValue:        return .blue
        case StorageCategory.buildArtifacts.rawValue: return .orange
        case StorageCategory.models.rawValue:        return .purple
        case StorageCategory.caches.rawValue:         return .teal
        case StorageCategory.cliTools.rawValue:       return .pink
        default:                                      return Palette.accent
        }
    }
}
