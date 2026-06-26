import Foundation
import OSLog

/// Log categories aligned with Forge feature areas.
public enum LogCategory: String, Sendable {
    case app
    case detector
    case cleanup
    case persistence
    case update
    case ui
}

extension Logger {
    /// The shared subsystem for all Forge log output.
    public static let subsystem = "com.forge.app"

    /// General application / lifecycle logs.
    public static let app = Logger(subsystem: subsystem, category: LogCategory.app.rawValue)

    /// Detector scan logs.
    public static let detector = Logger(subsystem: subsystem, category: LogCategory.detector.rawValue)

    /// Cleanup dry-run and commit logs.
    public static let cleanup = Logger(subsystem: subsystem, category: LogCategory.cleanup.rawValue)

    /// Persistence (SwiftData) logs.
    public static let persistence = Logger(subsystem: subsystem, category: LogCategory.persistence.rawValue)

    /// Update availability logs.
    public static let update = Logger(subsystem: subsystem, category: LogCategory.update.rawValue)

    /// SwiftUI / view-model logs.
    public static let ui = Logger(subsystem: subsystem, category: LogCategory.ui.rawValue)
}
