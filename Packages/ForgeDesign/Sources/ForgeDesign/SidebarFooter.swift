import SwiftUI

/// Sidebar footer in GitHub Desktop style: brand logo, version,
/// platform info, divider, scan status, environment health.
public struct SidebarFooter: View {
    /// Health-state indicator for `SidebarFooter`. Three cases map to the
    /// three colors used elsewhere in the design system (success / warning /
    /// critical).
    public enum HealthStatus {
        case healthy
        case warnings
        case critical

        /// Short label rendered next to the colored dot.
        public var label: String {
            switch self {
            case .healthy:  return "Healthy"
            case .warnings: return "Warnings"
            case .critical: return "Critical"
            }
        }

        /// Color used for the dot and (implicitly) the label.
        public var color: Color {
            switch self {
            case .healthy:  return Palette.success
            case .warnings: return Palette.warning
            case .critical: return Palette.critical
            }
        }
    }

    let appName: String
    let appVersion: String
    let lastScanRelative: String?
    let health: HealthStatus

    public init(
        appName: String = "Forge",
        appVersion: String = "0.5.0",
        lastScanRelative: String?,
        health: HealthStatus
    ) {
        self.appName = appName
        self.appVersion = appVersion
        self.lastScanRelative = lastScanRelative
        self.health = health
    }

    /// Backwards-compatible initializer that accepts the old
    /// `SidebarHealthStatus` enum (kept for source-compatibility with
    /// existing call sites that still use that type).
    public init(
        appVersion: String,
        lastScanRelative: String?,
        healthStatus: SidebarHealthStatus
    ) {
        self.appName = "Forge"
        self.appVersion = appVersion
        self.lastScanRelative = lastScanRelative
        switch healthStatus {
        case .healthy:  self.health = .healthy
        case .warnings: self.health = .warnings
        case .critical: self.health = .critical
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                ForgeLogo(style: .compact, size: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(appName)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Version \(appVersion)")
                        .font(Typography.caption2)
                        .foregroundStyle(Palette.tertiaryLabel)
                }
                Spacer()
            }

            Text(platformString)
                .font(Typography.caption2)
                .foregroundStyle(Palette.tertiaryLabel)

            Divider()

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(health.color)
                    .frame(width: 8, height: 8)
                Text("Environment \(health.label)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondaryLabel)
            }

            if let lastScanRelative {
                Text("Last scan \(lastScanRelative) ago")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.tertiaryLabel)
            } else {
                Text("Last scan: never")
                    .font(Typography.caption2)
                    .foregroundStyle(Palette.tertiaryLabel)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.controlBackground)
    }

    private var platformString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersionString
        let arch: String
        #if arch(arm64)
        arch = "Apple Silicon"
        #elseif arch(x86_64)
        arch = "Intel"
        #else
        arch = "Unknown"
        #endif
        return "macOS \(version) · \(arch)"
    }
}

/// Legacy health-state enum kept for source-compatibility. New code
/// should use `SidebarFooter.HealthStatus` instead.
public enum SidebarHealthStatus {
    case healthy
    case warnings
    case critical

    /// Short label rendered next to the colored dot.
    var label: String {
        switch self {
        case .healthy:  return "Healthy"
        case .warnings: return "Warnings"
        case .critical: return "Critical"
        }
    }

    /// Color used for the dot and (implicitly) the label.
    var color: Color {
        switch self {
        case .healthy:  return Palette.success
        case .warnings: return Palette.warning
        case .critical: return Palette.critical
        }
    }
}
