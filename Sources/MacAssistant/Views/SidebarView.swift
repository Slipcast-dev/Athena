import AppKit
import SwiftUI

/// Нативный короткий список сохраняет плотность стандартной боковой панели macOS.
struct SidebarView: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(selection: $selection) {
            Section("Mac Assistant") {
                ForEach(AppSection.allCases) { section in
                    if section == .agents {
                        Label {
                            Text(section.title)
                        } icon: {
                            AgentSidebarIcon()
                        }
                        .tag(section)
                    } else {
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Mac Assistant")
    }
}

/// Отдельная компактная подложка сохраняет портрет Афины читаемым как на
/// светлой боковой панели, так и в синем состоянии выбора. Без неё тёмные края
/// иллюстрации сливаются с системным акцентным цветом на малом размере.
private struct AgentSidebarIcon: View {
    var body: some View {
        Group {
            if let image = athenaImage {
                // SwiftUI `Image(name, bundle:)` ищет имя в каталоге ассетов и
                // может не отрисовать обычный PNG внутри SwiftPM bundle. Явно
                // загружаем файл через NSImage: это устойчиво для локальной
                // ресурсной папки и не зависит от способа упаковки ассетов.
                Image(nsImage: image)
                    // Растровая иллюстрация не должна наследовать tint
                    // выбранной строки и превращаться в одноцветное пятно.
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
            } else {
                // Запасной символ не оставляет пустой квадрат, если ресурс был
                // повреждён при ручной сборке сторонним упаковщиком.
                Image(systemName: "shield.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 22, height: 22)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        }
        .accessibilityLabel("Афина — агент")
    }

    /// `NSImage(contentsOf:)` читает точный URL PNG, а не полагается на
    /// неявный поиск по имени в asset catalog.
    private var athenaImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "AgentAthena", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
