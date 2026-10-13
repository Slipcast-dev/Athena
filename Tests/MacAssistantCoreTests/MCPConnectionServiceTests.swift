import XCTest
@testable import MacAssistantCore

final class MCPConnectionServiceTests: XCTestCase {
    func testHarnessConnectionCreatesSingleSafePatchEntry() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let service = MCPConnectionService(
            homeDirectory: home,
            // /bin/echo — системный исполняемый файл только для проверки записи
            // конфигурации; тест не запускает Codex или DeepSeek Harness.
            executableLocator: { URL(fileURLWithPath: "/bin/echo") }
        )

        let initialStatus = await service.status(for: .deepSeekHarness)
        XCTAssertEqual(initialStatus, .notConfigured)
        let firstConnection = try await service.connect(.deepSeekHarness)
        XCTAssertEqual(firstConnection, .configured)
        let repeatedConnection = try await service.connect(.deepSeekHarness)
        XCTAssertEqual(repeatedConnection, .configured)

        let patchURL = home.appendingPathComponent(".dsh/cordis.patch.yml")
        let patch = try String(contentsOf: patchURL, encoding: .utf8)
        XCTAssertEqual(patch.components(separatedBy: "id: mcp-mac-assistant").count - 1, 1)
        XCTAssertTrue(patch.contains("name: '@deepseek-ai/dsh-mcp-client'"))
        XCTAssertTrue(patch.contains("command: '/bin/echo'"))
        let finalStatus = await service.status(for: .deepSeekHarness)
        XCTAssertEqual(finalStatus, .configured)
    }

    func testHarnessDisconnectionRemovesOnlyMacAssistantEntry() async throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let service = MCPConnectionService(
            homeDirectory: home,
            executableLocator: { URL(fileURLWithPath: "/bin/echo") }
        )
        let patchURL = home.appendingPathComponent(".dsh/cordis.patch.yml")
        try FileManager.default.createDirectory(at: patchURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let unrelatedPatch = """
        - insert:
            - id: another-local-server
              name: '@example/mcp-client'
        """
        try unrelatedPatch.write(to: patchURL, atomically: true, encoding: .utf8)

        _ = try await service.connect(.deepSeekHarness)
        let result = try await service.disconnect(.deepSeekHarness)

        XCTAssertEqual(result, .notConfigured)
        let finalStatus = await service.status(for: .deepSeekHarness)
        XCTAssertEqual(finalStatus, .notConfigured)
        let retainedPatch = try String(contentsOf: patchURL, encoding: .utf8)
        XCTAssertTrue(retainedPatch.contains("id: another-local-server"))
        XCTAssertFalse(retainedPatch.contains("id: mcp-mac-assistant"))
    }
}
