import Foundation
#if canImport(Darwin)
import Darwin
#endif
@testable import ForgeDiagnostics

// MARK: - FixtureTree
//
// Test utility for building realistic on-disk directory trees inside a temp
// directory. Used by XcodeDiagnosticsTests (and future diagnostic tests) to
// avoid touching the real machine's `~/Library/Developer/Xcode`.
//
// Usage:
//     let tmp = try FixtureTree.createTemp { builder in
//         builder.file("Library/Developer/Xcode/DerivedData/ProjA/Build/file.o", size: 2_000_000)
//         builder.dir("Library/Developer/Xcode/Archives/Archive1")
//     }
//     defer { try? FileManager.default.removeItem(at: tmp) }
//     let diagnostics = XcodeDiagnostics(developerDirectory: tmp.appendingPathComponent("Library/Developer/Xcode"))
//     let issues = try await diagnostics.diagnose(context: DiagnosticsContext())

enum FixtureTree {

    /// Recursive directory builder. Each `file`/`dir` call creates one
    /// node relative to the temp root.
    final class Builder {
        fileprivate var filesToCreate: [(path: String, size: UInt64)] = []
        fileprivate var directoriesToCreate: [String] = []

        /// Creates a regular file at `path` (relative to the temp root)
        /// filled with `size` bytes of zeros.
        func file(_ path: String, size: UInt64) {
            filesToCreate.append((path: path, size: size))
        }

        /// Creates an empty directory at `path` (and any missing parents).
        func dir(_ path: String) {
            directoriesToCreate.append(path)
        }
    }

    /// Creates a temp directory and populates it according to `build`.
    /// Returns the root URL. Caller is responsible for removing it.
    static func createTemp(_ build: (Builder) -> Void) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ForgeFixture-\(UUID().uuidString)", isDirectory: true)

        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let builder = Builder()
        build(builder)

        // Create directories first.
        for dir in builder.directoriesToCreate {
            try fm.createDirectory(
                at: root.appendingPathComponent(dir, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        // Then files. Use sparse-file allocation (ftruncate) instead of
        // `Data(count: size).write(to:)` so fixtures reporting 20+ GB don't
        // actually consume 20+ GB on disk. APFS supports sparse files
        // natively; stat/fileSizeKey report the logical size either way.
        for (path, size) in builder.filesToCreate {
            let url = root.appendingPathComponent(path)
            try fm.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.createSparseFile(at: url, logicalSize: size)
        }

        return root
    }

    /// Creates a file at `url` with the given logical size using ftruncate.
    /// The file appears as `size` bytes to stat/FileManager but only
    /// allocates disk blocks for written data. This lets the fixtures
    /// report realistic sizes (5–20 GB) without exhausting the test
    /// machine's free space.
    static func createSparseFile(at url: URL, logicalSize: UInt64) throws {
        #if canImport(Darwin)
        let path = url.path
        let fd = open(path, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else {
            throw NSError(domain: "FixtureTree", code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "open() failed for \(path): \(String(cString: strerror(errno)))"
            ])
        }
        defer { close(fd) }
        if ftruncate(fd, off_t(logicalSize)) != 0 {
            throw NSError(domain: "FixtureTree", code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "ftruncate() failed for \(path): \(String(cString: strerror(errno)))"
            ])
        }
        #else
        // Non-Darwin fallback: write real bytes. Tests on macOS always
        // hit the sparse path above.
        try Data(count: Int(logicalSize)).write(to: url)
        #endif
    }

    /// Convenience: builds an Xcode-style fixture tree at
    /// `<tmp>/Library/Developer/Xcode` with DerivedData/Archives/
    /// iOS DeviceSupport populated. Returns the developer root URL.
    static func createXcodeFixture(
        derivedDataBytes: UInt64,
        archivesBytes: UInt64,
        deviceSupportBytes: UInt64,
        coreSimulatorCachesBytes: UInt64
    ) throws -> URL {
        try createTemp { builder in
            // DerivedData — split across 3 project dirs for realism.
            let ddPerProject = derivedDataBytes / 3
            for project in ["ProjectA", "ProjectB", "ProjectC"] {
                let ddRoot = "Library/Developer/Xcode/DerivedData/\(project)/Build/Products"
                // Create one fat file + a bunch of small object files.
                builder.file("\(ddRoot)/App.o", size: ddPerProject / 4)
                builder.file("\(ddRoot)/App.dSYM", size: ddPerProject / 4)
                builder.file("\(ddRoot)/Helpers.a", size: ddPerProject / 4)
                builder.file("\(ddRoot)/Other.txt", size: ddPerProject / 4)
            }
            // Archives — flat files at the top level.
            let archiveCount = max(1, Int(archivesBytes / 500_000_000))
            let perArchive = archivesBytes / UInt64(archiveCount)
            for i in 0..<archiveCount {
                builder.file(
                    "Library/Developer/Xcode/Archives/Archive-\(i).xcarchive",
                    size: perArchive
                )
            }
            // DeviceSupport — one dir per iOS version, sized like a real symbol cache.
            let dsPerVersion = deviceSupportBytes / 3
            for version in ["16.0", "16.1", "16.2"] {
                builder.file(
                    "Library/Developer/Xcode/iOS DeviceSupport/\(version)/Symbols.dSYM",
                    size: dsPerVersion
                )
            }
            // CoreSimulator caches — single large file.
            if coreSimulatorCachesBytes > 0 {
                builder.file(
                    "Library/Developer/CoreSimulator/Caches/com.apple.CoreSimulator.cache",
                    size: coreSimulatorCachesBytes
                )
            }
        }
    }

    /// Convenience: builds a minimal Xcode fixture with no scanning
    /// triggers (everything below the 1 GB threshold).
    static func createCleanXcodeFixture() throws -> URL {
        try createXcodeFixture(
            derivedDataBytes: 100_000_000,        // 100 MB
            archivesBytes: 50_000_000,             // 50 MB
            deviceSupportBytes: 200_000_000,       // 200 MB
            coreSimulatorCachesBytes: 300_000_000  // 300 MB
        )
    }

    /// Convenience: builds an Xcode fixture where every scan should trigger.
    static func createHeavyXcodeFixture() throws -> URL {
        try createXcodeFixture(
            derivedDataBytes: 18_400_000_000,      // 18.4 GB → critical
            archivesBytes: 6_200_000_000,         // 6.2 GB → warning
            deviceSupportBytes: 3_100_000_000,     // 3.1 GB → warning
            coreSimulatorCachesBytes: 4_500_000_000 // 4.5 GB → warning
        )
    }
}
