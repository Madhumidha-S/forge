import XCTest
import SwiftData
@testable import ForgeCore

@MainActor
final class AppEnvironmentTests: XCTestCase {

    func testEnvironmentComposesMockSlots() {
        let detectorRegistry = MockDetectorRegistry()
        let persistenceController = MockPersistenceController()
        let cleanupRegistry = MockCleanupServiceRegistry()
        let updateRegistry = MockUpdateProviderRegistry()

        let env = AppEnvironment(
            detectorRegistry: detectorRegistry,
            persistenceController: persistenceController,
            cleanupServiceRegistry: cleanupRegistry,
            updateProviderRegistry: updateRegistry
        )

        XCTAssertTrue(env.detectorRegistry as AnyObject === detectorRegistry as AnyObject)
        XCTAssertTrue(env.persistenceController as AnyObject === persistenceController as AnyObject)
        XCTAssertTrue(env.cleanupServiceRegistry as AnyObject === cleanupRegistry as AnyObject)
        XCTAssertTrue(env.updateProviderRegistry as AnyObject === updateRegistry as AnyObject)
    }

    func testLiveEnvironmentUsesNoOpDefaults() async {
        let env = await AppEnvironment.live()

        let detections = try? await env.detectorRegistry.scanAll()
        XCTAssertEqual(detections, [])

        // Persistence may resolve to a real on-disk store or a NoOp depending on
        // environment; we only assert the call is functional, not the contents.
        XCTAssertNoThrow(try env.persistenceController.fetchAll())

        let actions = await env.cleanupServiceRegistry.availableActions()
        XCTAssertEqual(actions.count, 0)

        let version = try? await env.updateProviderRegistry.latestVersion(for: .git)
        XCTAssertNil(version)
    }
}

private final class MockDetectorRegistry: DetectorRegistryProtocol {
    func scanAll() async throws -> [ToolDetection] { [] }
    func register(_ detector: any ToolDetectorProtocol) async {}
}

private final class MockPersistenceController: PersistenceControllerProtocol {
    var container: ModelContainer {
        // swiftlint:disable:next force_try
        try! ModelContainer(for: Schema([ToolRecord.self]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    func save(_ records: [ToolRecord]) throws {}
    func fetchAll() throws -> [ToolRecord] { [] }
}

private final class MockCleanupServiceRegistry: CleanupServiceRegistryProtocol {
    func availableActions() async -> [any CleanupActionProtocol] { [] }
}

private final class MockUpdateProviderRegistry: UpdateProviderRegistryProtocol {
    func latestVersion(for toolID: ToolID) async throws -> SemVer? { nil }
}
