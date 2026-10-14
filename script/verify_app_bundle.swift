import AppKit

// Проверяем готовый bundle, а не только наличие исходного PNG. NSWorkspace
// использует тот же механизм разрешения иконки файла, который нужен Finder.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("usage: swift script/verify_app_bundle.swift <Athena.app> <icon-preview.png>")
}
let appURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
guard let bundle = Bundle(url: appURL),
      bundle.object(forInfoDictionaryKey: "CFBundleName") as? String == "Athena",
      bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Athena",
      bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String == "com.macassistant.app",
      bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String == "Athena.icns",
      let iconURL = bundle.url(forResource: "Athena", withExtension: "icns"),
      let icon = NSImage(contentsOf: iconURL), icon.isValid,
      let executable = bundle.executableURL,
      FileManager.default.isExecutableFile(atPath: executable.path) else {
    fatalError("Неверное имя, иконка или исполняемый файл Athena.app")
}
let finderIcon = NSWorkspace.shared.icon(forFile: appURL.path)
finderIcon.size = NSSize(width: 256, height: 256)
guard let tiff = finderIcon.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Не удалось прочитать Finder-иконку Athena")
}
try png.write(to: URL(fileURLWithPath: arguments[2]))
print("Bundle: Athena; ICNS: \(iconURL.lastPathComponent); Finder icon rendered")
