import SwiftUI

/// Нативный короткий список сохраняет плотность стандартной боковой панели macOS.
struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("Mac Assistant") {
                ForEach(AppSection.allCases) { section in
                    // Все пункты используют контурные SF Symbols. Благодаря
                    // этому macOS одинаково применяет системный акцентный цвет
                    // и белый цвет текста/иконки для выбранной строки.
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac Assistant")
    }
}
