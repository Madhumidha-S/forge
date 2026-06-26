import SwiftUI

/// Single row in the Tools list.
public struct ToolRow: View {
    public let model: ToolUIModel
    public let name: String

    /// Primary initializer that renders a full tool model.
    public init(model: ToolUIModel) {
        self.model = model
        self.name = model.displayName
    }

    /// Convenience initializer that renders a name-only placeholder.
    public init(name: String) {
        self.name = name
        self.model = ToolUIModel(
            id: UUID(),
            toolIdRaw: name.lowercased(),
            displayName: name,
            version: nil,
            installPath: nil,
            diskUsageBytes: nil,
            isHealthy: true,
            lastChecked: Date()
        )
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.headline)

                Group {
                    if let version = model.version {
                        Text(version)
                    } else {
                        Text("not installed")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let installPath = model.installPath {
                    Text(installPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            Image(systemName: model.isHealthy ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(model.isHealthy ? .green : .red)
                .accessibilityLabel(model.isHealthy ? "Healthy" : "Unhealthy")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ToolRow(name: "Example")
}

#Preview {
    ToolRow(model: ToolUIModel(
        id: UUID(),
        toolIdRaw: "node",
        displayName: "Node.js",
        version: "v20.10.0",
        installPath: "/usr/local/bin/node",
        diskUsageBytes: 42_000_000,
        isHealthy: true,
        lastChecked: Date()
    ))
}
