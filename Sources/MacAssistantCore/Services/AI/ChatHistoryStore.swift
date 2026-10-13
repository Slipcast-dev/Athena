import Foundation

public actor ChatHistoryStore {
    private let defaults: UserDefaults
    private let key = "chatConversations"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load() -> [ChatConversation] { (try? defaults.data(forKey: key).map { try JSONDecoder().decode([ChatConversation].self, from: $0) }) ?? [] }
    public func save(_ conversations: [ChatConversation]) throws { defaults.set(try JSONEncoder().encode(conversations), forKey: key) }
}
