import SwiftUI
import AppKit
import ForgeCore
import ForgeDesign

/// Inspector panel for the Tools section.
///
/// Header: tool name + version (typographic, no giant icon).
/// Body: details section + actions section.
/// No card chrome — sections are separated by hairlines.
public struct ToolsInspectorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityStore: ActivityStore
    @EnvironmentObject private var viewModel: ToolsViewModel

    private let toolID: ToolID

    public init(toolID: ToolID) {
        self.toolID = toolID
    }

    public var body: some View {
        Group {
            if let tool = currentTool {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection(for: tool)

                        InspectorSection("Details") {
                            KeyValueRow("Version", tool.version ?? "—")
                            KeyValueRow("Path", tool.installPath ?? "—")
                            KeyValueRow("Disk Usage", tool.diskUsageFormatted)
                            KeyValueRow(
                                "Last Checked",
                                tool.lastChecked.formatted(.relative(presentation: .named))
                            )
                            KeyValueRow(
                                "Status",
                                tool.isHealthy ? "Healthy" : "Unhealthy"
                            )
                            KeyValueRow(
                                "Updates",
                                tool.hasUpdateText
                            )
                        }

                        InspectorSection("Actions") {
                            VStack(spacing: Spacing.xs) {
                                Button("Open in Finder") {
                                    revealInFinder(tool: tool)
                                }
                                .controlSize(.regular)
                                .disabled(tool.installPath == nil)
                                .frame(maxWidth: .infinity)

                                Button("Analyze Storage") {
                                    analyze(tool: tool)
                                }
                                .controlSize(.regular)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Spacing.m)
                }
            } else {
                VStack(spacing: Spacing.s) {
                    Image(systemName: "questionmark.circle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Tool unavailable")
                        .font(Typography.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Looks up the current `ToolUIModel` for `toolID` from the shared
    /// view model.
    private var currentTool: ToolUIModel? {
        viewModel.tools.first { $0.toolIdRaw == toolID.rawValue }
    }

    /// Typographic header — tool name and version, with a small inline
    /// SF Symbol as a soft accent. No card chrome.
    private func headerSection(for tool: ToolUIModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: tool.systemImageName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.secondaryLabel)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .font(Typography.title3)
                if let version = tool.version {
                    Text(version)
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(Palette.tertiaryLabel)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.s)
    }

    private func revealInFinder(tool: ToolUIModel) {
        guard let path = tool.installPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func analyze(tool: ToolUIModel) {
        guard let toolID = ToolID(rawValue: tool.toolIdRaw) else { return }
        Task {
            _ = try? await environment.diagnosticsEngine.analyze(toolID: toolID)
            activityStore.info("Analyzed storage for \(tool.displayName)")
        }
    }
}
