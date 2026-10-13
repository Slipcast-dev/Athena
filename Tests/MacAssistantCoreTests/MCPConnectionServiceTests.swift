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
}
