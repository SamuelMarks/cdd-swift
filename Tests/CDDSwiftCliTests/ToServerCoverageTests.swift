import XCTest
@testable import cdd_swift_cli

final class ToServerCoverageTests: XCTestCase {
    func testToServerWithDBAndSeeder() async throws {
        var cmd = try ToServer.parse(["--input", "comprehensive-openapi.json", "-o", "/tmp/cdd-test-server-coverage", "--tests"])
        try await cmd.run()
    }
}
