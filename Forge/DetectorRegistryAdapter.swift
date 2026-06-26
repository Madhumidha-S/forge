import Foundation
import ForgeCore
import ForgeDetectors

/// Bridges the real `DetectorRegistry` actor from `ForgeDetectors` to the
/// `DetectorRegistryProtocol` boundary used by `ForgeCore` and `ForgeUI`.
///
/// The adapter is `@MainActor`-isolated so it can be stored in the SwiftUI
/// dependency graph and `AppEnvironment` without crossing concurrency domains.
@MainActor
final class LiveDetectorRegistryAdapter: DetectorRegistryProtocol {
    private let actor: DetectorRegistry

    init(actor: DetectorRegistry) {
        self.actor = actor
    }

    /// The core protocol uses a placeholder detector type. For the scaffold,
    /// detectors are pre-registered directly on the wrapped `DetectorRegistry`
    /// in `ForgeApp`, so this adapter boundary is intentionally a no-op.
    func register(_ detector: any ToolDetectorProtocol) async {
        // no-op: real detectors are registered on the wrapped actor.
    }

    /// Runs every registered detector and translates the richer
    /// `DetectionResult` values into the shared `ToolDetection` shape.
    func scanAll() async throws -> [ToolDetection] {
        let results = await actor.scanAll()
        return results.map { result in
            ToolDetection(
                id: UUID(),
                toolID: result.toolId,
                displayName: result.toolId.rawValue,
                version: result.version.map { "\($0.major).\($0.minor).\($0.patch)" },
                installPath: result.installPath.flatMap { URL(fileURLWithPath: $0) },
                diskUsageBytes: result.diskUsageBytes.map { UInt64($0) },
                isHealthy: result.runningStatus != .unknown
            )
        }
    }
}
