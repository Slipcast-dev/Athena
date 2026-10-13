import SwiftUI
import MacAssistantCore

struct DashboardView: View {
    /// Зарезервировано для ViewModel блока диагностики; пока интерфейс не
    /// инициирует системные вызовы и не показывает недостоверные показатели.
    let container: AppContainer

    var body: some View {
        FeatureScreen(title: "Обзор", state: .ready) {
            ContentUnavailableView(
                "Показатели Mac появятся здесь",
                systemImage: "gauge.with.dots.needle.33percent",
                description: Text("В следующем этапе диагностики будут добавлены реальные данные CPU, памяти и накопителя.")
            )
        }
    }
}
