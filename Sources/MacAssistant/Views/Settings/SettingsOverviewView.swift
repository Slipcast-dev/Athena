import SwiftUI

struct SettingsOverviewView: View {
    var body: some View {
        FeatureScreen(title: "Настройки", state: .ready) {
            ContentUnavailableView(
                "Настройки приложения",
                systemImage: "gearshape",
                description: Text("Настройка диагностических порогов и системного промпта будет добавляться вместе с соответствующими функциями.")
            )
            .toolbar {
                SettingsLink {
                    Text("Открыть настройки…")
                }
            }
        }
    }
}
