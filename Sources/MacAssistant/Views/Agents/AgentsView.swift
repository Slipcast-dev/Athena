import SwiftUI

struct AgentsView: View {
    var body: some View {
        FeatureScreen(title: "Агенты", state: .ready) {
            ContentUnavailableView(
                "Agent Bridge отключён",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text("Внешний агент можно будет подключить только после проверки его документированного протокола.")
            )
        }
    }
}
