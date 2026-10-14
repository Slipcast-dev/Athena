import XCTest
import SwiftUI
import AppKit
import MacAssistantCore
@testable import MacAssistant

private struct LayoutAI: AIProviding {
    func availableModels(for profile: AIProviderProfile) async throws -> [AIModel] { [] }
    func send(messages: [ChatMessage], using profile: AIProviderProfile, modelID: String) async throws -> ChatMessage {
        ChatMessage(role: .assistant, content: "Локальный тест")
    }
}

private struct LayoutProfiles: AIProfileManaging {
    let values: [AIProviderProfile]
    func profiles() async -> [AIProviderProfile] { values }
    func save(profile: AIProviderProfile, apiKey: String?) async throws { }
    func delete(profileID: UUID) async throws { }
}

/// Снимки реальных SwiftUI-компонентов через NSHostingView, без сети и изменения
/// пользовательской истории. Они дополняют тесты поведения визуальной проверкой.
@MainActor
final class ChatLayoutTests: XCTestCase {
    func testChatLayoutsInBothThemesAndCompactWindow() async throws {
        let output = ProcessInfo.processInfo.environment["MACASSISTANT_UI_SNAPSHOTS_DIR"]
        for populated in [false, true] {
            let suite = "ChatLayout.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let history = ChatHistoryStore(defaults: defaults)
            if populated {
                try await history.upsert(ChatConversation(title: "Почему Mac работает медленно?", messages: [
                    ChatMessage(role: .user, content: "Почему Mac работает медленно?"),
                    ChatMessage(role: .assistant, content: "Давайте проверим основные показатели.\n\n1. Откройте раздел «Обзор» и посмотрите загрузку CPU.\n2. Проверьте давление памяти.\n3. Убедитесь, что на накопителе достаточно свободного места.\n\nПришлите показатели — помогу разобраться.")
                ]))
            }
            let profile = AIProviderProfile(name: "Локальный провайдер", kind: .ollama,
                                            baseURL: URL(string: "http://localhost:11434/api")!, defaultModelID: "local-model")
            let vm = AIChatViewModel(ai: LayoutAI(), manager: LayoutProfiles(values: populated ? [profile] : []), history: history)
            await vm.load()
            if populated { vm.input = "Помоги разобрать эти показатели" }
            for theme in [ColorScheme.light, .dark] {
                for width: CGFloat in [600, 1000] {
                    let root = AIChatView(viewModel: vm).environment(\.colorScheme, theme)
                        .frame(width: width, height: 620)
                    let host = NSHostingView(rootView: root)
                    host.frame = NSRect(x: 0, y: 0, width: width, height: 620)
                    host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, Int(width))
                    XCTAssertGreaterThanOrEqual(bitmap.pixelsHigh, 620)
                    if let output {
                        let directory = URL(fileURLWithPath: output, isDirectory: true)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let name = "chat-\(populated ? "messages" : "welcome")-\(theme == .light ? "light" : "dark")-\(Int(width)).png"
                        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        try png.write(to: directory.appendingPathComponent(name))
                    }
                }
            }
        }
    }
}
