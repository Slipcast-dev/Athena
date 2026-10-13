import XCTest
@testable import MacAssistantCore

final class ChatHistoryTests: XCTestCase {
    func testHistoryRoundTripDoesNotContainProviderSecrets() async throws {
        let suite = "ChatHistoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ChatHistoryStore(defaults: defaults)
        let conversation = ChatConversation(title: "Тест", messages: [ChatMessage(role: .user, content: "Привет")])
        try await store.save([conversation])
        let restored = await store.load()
        XCTAssertEqual(restored, [conversation])
    }
}
