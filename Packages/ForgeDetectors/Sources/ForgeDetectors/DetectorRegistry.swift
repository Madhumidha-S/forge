import Foundation
import OSLog
import ForgeCore

extension Logger {
    /// Registry-scoped logger for detector registration and scan orchestration.
    public static let detectorRegistry = Logger(
        subsystem: subsystem,
        category: "DetectorRegistry"
    )
}

/// An actor that registers `ToolDetector` conformers and runs them concurrently.
public actor DetectorRegistry {
    private var detectors: [ToolID: any ToolDetector] = [:]
    private let logger = Logger.detectorRegistry

    public init() {}

    /// Registers a detector, replacing any existing detector with the same `id`.
    public func register(_ detector: any ToolDetector) {
        detectors[detector.id] = detector
        logger.info("Registered detector \(detector.id.rawValue, privacy: .public)")
    }

    /// Returns all registered detector IDs sorted by raw value.
    public func registeredIDs() -> [ToolID] {
        Array(detectors.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// Runs every registered detector concurrently and returns the results as a flat array.
    ///
    /// Per-detector errors are swallowed and converted to `DetectionResult.failed(...)`
    /// entries so a single broken detector cannot abort the whole scan. The UI layer
    /// can then iterate over the array uniformly without handling `Result` types.
    public func scanAll(
        timeout: Duration = .seconds(15)
    ) async -> [DetectionResult] {
        var results: [DetectionResult] = []

        await withTaskGroup(of: DetectionResult.self) { group in
            for detector in detectors.values {
                group.addTask {
                    do {
                        return try await detector.detect()
                    } catch let error as DetectionError {
                        return DetectionResult.failed(toolId: detector.id, error: error)
                    } catch {
                        return DetectionResult.failed(
                            toolId: detector.id,
                            error: .underlying(String(describing: error))
                        )
                    }
                }
            }

            for await result in group {
                results.append(result)
            }
        }

        // Sort by tool id for stable UI ordering.
        return results.sorted { $0.toolId.rawValue < $1.toolId.rawValue }
    }

    /// Runs every registered detector concurrently and returns a map of typed results.
    ///
    /// Like `scanAll()` but preserves the `Result` discriminator so callers can
    /// branch on success vs. failure without inspecting healthChecks.
    public func scanAllTyped(
        timeout: Duration = .seconds(15)
    ) async -> [ToolID: Result<DetectionResult, DetectionError>] {
        var results: [ToolID: Result<DetectionResult, DetectionError>] = [:]

        await withTaskGroup(of: (ToolID, Result<DetectionResult, DetectionError>).self) { group in
            for detector in detectors.values {
                group.addTask {
                    let result: Result<DetectionResult, DetectionError>
                    do {
                        let value = try await detector.detect()
                        result = .success(value)
                    } catch let error as DetectionError {
                        result = .failure(error)
                    } catch {
                        result = .failure(.underlying(String(describing: error)))
                    }
                    return (detector.id, result)
                }
            }

            for await (id, result) in group {
                results[id] = result
            }
        }

        return results
    }

    /// Runs a single detector by ID.
    ///
    /// - Throws: `DetectionError.notFound` if no detector with the given ID is registered.
    public func detect(_ id: ToolID) async throws -> DetectionResult {
        guard let detector = detectors[id] else {
            throw DetectionError.notFound
        }
        return try await detector.detect()
    }
}
