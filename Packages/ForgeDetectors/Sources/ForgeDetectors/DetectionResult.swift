import Foundation
import ForgeCore

/// The runtime state of a detected developer tool.
public struct DetectionResult: Sendable, Equatable {
    public let toolId: ToolID
    public let version: SemVer?
    public let installPath: String?
    public let diskUsageBytes: Int64?
    public let configPath: String?
    public let runningStatus: RunningStatus?
    public let healthChecks: [HealthCheck]
    public let lastChecked: Date

    public init(
        toolId: ToolID,
        version: SemVer? = nil,
        installPath: String? = nil,
        diskUsageBytes: Int64? = nil,
        configPath: String? = nil,
        runningStatus: RunningStatus? = nil,
        healthChecks: [HealthCheck] = [],
        lastChecked: Date = Date()
    ) {
        self.toolId = toolId
        self.version = version
        self.installPath = installPath
        self.diskUsageBytes = diskUsageBytes
        self.configPath = configPath
        self.runningStatus = runningStatus
        self.healthChecks = healthChecks
        self.lastChecked = lastChecked
    }
}

extension DetectionResult {
    /// Returns a failed detection result for the given tool ID and error.
    ///
    /// Used by `DetectorRegistry.scanAll()` to flatten per-detector failures
    /// into the same `[DetectionResult]` shape as successes, so a single
    /// broken detector cannot abort the whole scan.
    public static func failed(toolId: ToolID, error: DetectionError) -> DetectionResult {
        DetectionResult(
            toolId: toolId,
            version: nil,
            installPath: nil,
            diskUsageBytes: nil,
            configPath: nil,
            runningStatus: .unknown,
            healthChecks: [HealthCheck(name: "detection", passed: false, detail: String(describing: error))]
        )
    }
}

/// Whether a tool is currently executing.
public enum RunningStatus: String, Sendable, Codable, Equatable {
    case running
    case stopped
    case unknown
}

/// A single health check performed against a detected tool.
public struct HealthCheck: Sendable, Equatable {
    public let name: String
    public let passed: Bool
    public let detail: String?

    public init(name: String, passed: Bool, detail: String? = nil) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}
