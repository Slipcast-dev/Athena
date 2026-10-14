import SwiftUI

/// Семантическая палитра macOS сохраняет системный контраст в обеих темах.
/// Размеры централизованы: лента и редактор используют одну читаемую колонку.
enum ChatStyle {
    static let columnWidth: CGFloat = 760
    static let pageInset: CGFloat = 24
    static let smallGap: CGFloat = 8
    static let gap: CGFloat = 16
    static let sectionGap: CGFloat = 32
    static let composerRadius: CGFloat = 24
    static let bubbleRadius: CGFloat = 20
    static let bodyFont = Font.system(size: 15)
    static let titleFont = Font.system(size: 30, weight: .semibold)
    static let surface = Color(nsColor: .textBackgroundColor)
    static let softSurface = Color.primary.opacity(0.06)
    static let border = Color(nsColor: .separatorColor)
}
