import XCTest
@testable import cdd_swift_cli

final class ToServerCoverageTests: XCTestCase {
    func testToServerWithDBAndSeeder() async throws {
        let outDir = "/tmp/cdd-test-server-coverage"
        var cmd = try ToServer.parse(["--input", "comprehensive-openapi.json", "-o", outDir, "--tests"])
        try await cmd.run()
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Package.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Entrypoint.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Routes/Routes.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Sources/GeneratedServer/Mocks/DatabaseSeeder.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/StubModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/EphemeralModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/SeededModeTests.swift"))
        XCTAssertTrue(WASIFileHelpers.fileExists(at: "\(outDir)/Tests/GeneratedServerTests/AuthMiddlewareTests.swift"))
    }
}
