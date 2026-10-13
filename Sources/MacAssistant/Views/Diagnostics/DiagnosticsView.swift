import SwiftUI

struct DiagnosticsView: View {
    var body: some View {
        FeatureScreen(title: "Диагностика", state: .ready) {
            ContentUnavailableView(
                "Диагностика ещё не запускалась",
                systemImage: "stethoscope",
                description: Text("Сбор системных показателей и рекомендации будут добавлены в блоке диагностики.")
            )
        }
    }
}
