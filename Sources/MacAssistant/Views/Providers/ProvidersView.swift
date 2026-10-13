import SwiftUI

struct ProvidersView: View {
    var body: some View {
        FeatureScreen(title: "ИИ-провайдеры", state: .ready) {
            ContentUnavailableView(
                "Профили не добавлены",
                systemImage: "network",
                description: Text("Управление ключами в Keychain и профилями провайдеров будет реализовано отдельно.")
            )
        }
    }
}
