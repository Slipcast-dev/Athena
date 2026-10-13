import SwiftUI

struct StorageView: View {
    var body: some View {
        FeatureScreen(title: "Накопитель", state: .ready) {
            ContentUnavailableView(
                "Каталог для анализа не выбран",
                systemImage: "internaldrive",
                description: Text("В блоке анализа накопителя появится безопасный выбор каталогов и отменяемое сканирование.")
            )
        }
    }
}
