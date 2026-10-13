import SwiftUI

struct AIChatView: View {
    var body: some View {
        FeatureScreen(title: "ИИ-помощник", state: .ready) {
            ContentUnavailableView(
                "Подключите ИИ-провайдера",
                systemImage: "bubble.left.and.bubble.right",
                description: Text("Чат станет доступен после настройки безопасного профиля провайдера.")
            )
        }
    }
}
