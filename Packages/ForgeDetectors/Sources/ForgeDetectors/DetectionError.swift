import Foundation

/// A typed error describing why a detector failed.
public enum DetectionError: Error, Sendable, Equatable {
    case notFound
    case timeout(seconds: Double)
    case permissionDenied(path: String)
    case malformedOutput(detail: String)
    case underlying(String)
}
