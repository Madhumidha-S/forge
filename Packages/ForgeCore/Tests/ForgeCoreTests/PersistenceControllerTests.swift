import XCTest
import SwiftData
@testable import ForgeCore

@MainActor
final class PersistenceControllerTests: XCTestCase {
    func testInMemoryStorePersistsAndFetches() throws {
        let controller = try PersistenceController(inMemory: true)
        let context = controller.mainContext

        let record = ToolRecord(
            toolIdRaw: "node",
            displayName: "Node.js",
            versionMajor: 22,
            versionMinor: 16,
            versionPatch: 0,
            installPath: "/usr/local/bin/node"
        )
        context.insert(record)
        try context.save()

        let descriptor = FetchDescriptor<ToolRecord>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.toolIdRaw, "node")
        XCTAssertEqual(fetched.first?.versionMajor, 22)
    }

    func testNoOpPersistenceControllerIsSafe() throws {
        let env = AppEnvironment.live()
        XCTAssertNoThrow(try env.persistenceController.fetchAll())
    }
}
