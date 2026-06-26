import Foundation
import SwiftData
import OSLog

@MainActor
public final class PersistenceController: PersistenceControllerProtocol {
    public func save(_ records: [ToolRecord]) throws {
        for record in records {
            mainContext.insert(record)
        }
        try mainContext.save()
    }

    public func fetchAll() throws -> [ToolRecord] {
        let descriptor = FetchDescriptor<ToolRecord>(
            sortBy: [SortDescriptor(\.lastChecked, order: .reverse)]
        )
        return try mainContext.fetch(descriptor)
    }

    public let container: ModelContainer
    private let logger = Logger.persistence

    public static let storeURL: URL = {
        let fm = FileManager.default
        let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let base = support ?? fm.temporaryDirectory
        return base.appendingPathComponent("Forge.store")
    }()

    public init(inMemory: Bool = false) throws {
        let schema = Schema([ToolRecord.self])
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                url: Self.storeURL,
                allowsSave: true
            )
        }
        self.container = try ModelContainer(for: schema, configurations: [configuration])
        logger.info("PersistenceController initialized at \(Self.storeURL.path, privacy: .public)")
    }

    /// Convenience accessor for the main-actor context.
    public var mainContext: ModelContext { container.mainContext }
}
