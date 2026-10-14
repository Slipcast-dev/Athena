import XCTest
import Yams
@testable import MacAssistantCore

final class MCPConnectionServiceTests: XCTestCase {
    func testStructuredRemovalPreservesNeighborsAndExactIDsInDifferentFormats() async throws {
        let variants = [
            """
            - insert:
                - id: before
                  config: {port: 123, enabled: true, value: '001'}
                - name: client
                  id: "mcp-mac-assistant"
                - id: mcp-mac-assistant-extra
                - id: after
              other: retained
            - remove: [unrelated]
            """,
            """
            [{insert: [{id: before, config: {port: 123, enabled: true, value: '001'}}, {name: client, id: 'mcp-mac-assistant'}, {id: mcp-mac-assistant-extra}, {id: after}], other: retained}, {remove: [unrelated]}]
            """
        ]
        for variant in variants {
            let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: home) }
            let file = home.appendingPathComponent(".dsh/cordis.patch.yml")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try variant.write(to: file, atomically: true, encoding: .utf8)
            let service = MCPConnectionService(homeDirectory: home, executableLocator: { URL(fileURLWithPath: "/bin/echo") })
            let status = await service.status(for: .deepSeekHarness)
            XCTAssertEqual(status, .configured)
            _ = try await service.connect(.deepSeekHarness)
            XCTAssertEqual(try String(contentsOf: file), variant, "Повторное подключение не меняет существующий файл")
            _ = try await service.disconnect(.deepSeekHarness)
            let retained = try XCTUnwrap(Yams.compose(yaml: String(contentsOf: file)))
            let operations = try XCTUnwrap(retained.sequence)
            let entries = try XCTUnwrap(operations[0]["insert"]?.sequence)
            XCTAssertEqual(entries.compactMap { $0["id"]?.string }, ["before", "mcp-mac-assistant-extra", "after"])
            XCTAssertEqual(entries[0]["config"]?["value"]?.string, "001")
            XCTAssertEqual(entries[0]["config"]?["enabled"]?.bool, true)
            XCTAssertEqual(operations[0]["other"]?.string, "retained")
            XCTAssertEqual(operations[1]["remove"]?.sequence?.first?.string, "unrelated")
            _ = try await service.disconnect(.deepSeekHarness)
            _ = try await service.connect(.deepSeekHarness)
            _ = try await service.connect(.deepSeekHarness)
            let connected = try XCTUnwrap(Yams.compose(yaml: String(contentsOf: file)))
            let matches = connected.sequence!.flatMap { $0["insert"]?.sequence.map(Array.init) ?? [] }
                .filter { $0["id"]?.string == "mcp-mac-assistant" }
            XCTAssertEqual(matches.count, 1)
        }
    }

    func testMalformedYAMLIsNeverOverwritten() async throws {
        for yaml in ["- insert: [broken", "- insert: []\n---\n- insert: []", "- insert: wrong", "- insert:\n  - id: neighbor\n    id: mcp-mac-assistant"] {
            let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: home) }
            let file = home.appendingPathComponent(".dsh/cordis.patch.yml")
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try yaml.write(to: file, atomically: true, encoding: .utf8)
            let service = MCPConnectionService(homeDirectory: home, executableLocator: { URL(fileURLWithPath: "/bin/echo") })
            do { _ = try await service.connect(.deepSeekHarness); XCTFail("Ожидалась ошибка YAML") } catch { }
            do { _ = try await service.disconnect(.deepSeekHarness); XCTFail("Ожидалась ошибка YAML") } catch { }
            XCTAssertEqual(try String(contentsOf: file), yaml)
        }
    }

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
