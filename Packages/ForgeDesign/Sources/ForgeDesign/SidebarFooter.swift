import SwiftUI

/// Minimal sidebar footer.
///
/// Two lines only — app name and version. Health, scan time, platform,
/// and architecture details live on the Overview page; the sidebar
/// stays calm at the bottom.
public struct SidebarFooter: View {
    let appName: String
    let appVersion: String

    public init(
        appName: String = "Forge",
        appVersion: String = "0.5.0"
    ) {
        self.appName = appName
        self.appVersion = appVersion
    }

    /// Backwards-compatible initializer for callers that pass the legacy
    /// `lastScanRelative` / `health` arguments. Those fields are
    /// discarded — they moved to the Overview page.
    public init(
        appName: String = "Forge",
        appVersion: String = "0.5.0",
        lastScanRelative: String?,
        health: HealthStatus
    ) {
        self.appName = appName
        self.appVersion = appVersion
    }

    /// Backwards-compatible initializer for legacy `SidebarHealthStatus`
    /// enum callers.
    public init(
        appVersion: String,
        lastScanRelative: String?,
        healthStatus: SidebarHealthStatus
    ) {
        self.appName = "Forge"
        self.appVersion = appVersion
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(appName)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
            Text("v\(appVersion)")
                .font(Typography.caption2.monospacedDigit())
                .foregroundStyle(Palette.tertiaryLabel)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Health status enum kept for source-compatibility with prior
    /// callers. No longer rendered by the footer.
    public enum HealthStatus {
        case healthy
        case warnings
        case critical

        public var label: String {
            switch self {
            case .healthy:  return "Healthy"
            case .warnings: return "Warnings"
            case .critical: return "Critical"
            }
        }

        public var color: Color {
            switch self {
            case .healthy:  return Palette.success
            case .warnings: return Palette.warning
            case .critical: return Palette.critical
            }
        }
    }
}

/// Legacy health-state enum kept for source-compatibility.
public enum SidebarHealthStatus {
    case healthy
    case warnings
    case critical

    var label: String {
        switch self {
        case .healthy:  return "Healthy"
        case .warnings: return "Warnings"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .healthy:  return Palette.success
        case .warnings: return Palette.warning
        case .critical: return Palette.critical
        }
    }
}
