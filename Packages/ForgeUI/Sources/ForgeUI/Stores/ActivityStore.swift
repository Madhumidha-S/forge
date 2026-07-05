import Foundation
import Combine
import SwiftUI
import OSLog

/// In-memory ring buffer of recent app events. Backs the Activity
/// screen in the sidebar.
///
/// Phase 4J — last 200 entries, in-memory only. No SwiftData persistence
/// in this phase; the architecture doc keeps persistence deferred.
///
/// The store is `@MainActor` because the Activity screen reads `events`
/// directly via `@StateObject` and SwiftUI view bindings are main-actor.
/// `append()` is main-actor isolated for the same reason.
@MainActor
public final class ActivityStore: ObservableObject {
    /// One log entry. Mirrors the shape of an `OSLog` record minus the
    /// subsystem (we use the single app subsystem) so the View doesn't
    /// need to import OSLog directly.
    public struct Entry: Identifiable, Hashable {
        public enum Level: String, Hashable, CaseIterable {
            case debug, info, notice, warning, error, fault
        }

        public let id = UUID()
        public let timestamp: Date
        public let level: Level
        public let message: String
        public let subsystem: String?

        public init(timestamp: Date = Date(), level: Level, message: String, subsystem: String? = nil) {
            self.timestamp = timestamp
            self.level = level
            self.message = message
            self.subsystem = subsystem
        }
    }

    /// Maximum number of entries kept in memory. Newer entries push
    /// older ones off the end.
    public static let maxEntries = 200

    @Published public private(set) var entries: [Entry] = []

    private let logger = Logger(subsystem: "forge.app.activity", category: "store")

    public init() {}

    /// Append a new entry. The buffer is trimmed to `maxEntries` from
    /// the front (oldest entries fall off when the limit is exceeded).
    /// Also mirrors the entry to `OSLog` so the OS Console.app shows it.
    public func append(level: Entry.Level, message: String, subsystem: String? = nil) {
        let entry = Entry(level: level, message: message, subsystem: subsystem)
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        logToOSLog(entry)
    }

    /// Convenience for `info`-level entries.
    public func info(_ message: String) {
        append(level: .info, message: message)
    }

    /// Convenience for `warning`-level entries.
    public func warning(_ message: String) {
        append(level: .warning, message: message)
    }

    /// Convenience for `error`-level entries.
    public func error(_ message: String) {
        append(level: .error, message: message)
    }

    /// Clear all entries.
    public func clear() {
        entries.removeAll()
    }

    // MARK: - OSLog mirror

    private func logToOSLog(_ entry: Entry) {
        switch entry.level {
        case .debug:    logger.debug("\(entry.message, privacy: .public)")
        case .info:     logger.info("\(entry.message, privacy: .public)")
        case .notice:   logger.notice("\(entry.message, privacy: .public)")
        case .warning:  logger.warning("\(entry.message, privacy: .public)")
        case .error:    logger.error("\(entry.message, privacy: .public)")
        case .fault:    logger.fault("\(entry.message, privacy: .public)")
        }
    }
}
