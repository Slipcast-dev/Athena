# Тестовые установщики Mac Assistant

Новая сборка, подготовленная локально:
[MacAssistant-0.1.2-unsigned.pkg](MacAssistant-0.1.2-unsigned.pkg).
Содержит обновлённый интерфейс чата; подробности —
[дизайн](../docs/CHAT_DESIGN.md) и [аудит](../docs/AUDIT_0.1.2.md).
Версия 0.1.2 ещё не опубликована в GitHub Releases.

Ранее опубликованный установщик:

[Скачать MacAssistant-0.1.1-unsigned.pkg](MacAssistant-0.1.1-unsigned.pkg)

macOS 14+, **Apple Silicon (arm64)**. Эта сборка не предназначена для Intel Mac.
Пакет **не подписан Apple Developer ID** и **не нотарифицирован Apple**.
Gatekeeper может блокировать установку. Он опубликован как предварительная
сборка для осознанного тестирования.

Контрольная сумма приведена в [SHA256SUMS.txt](SHA256SUMS.txt).
Проверка из этой папки: `shasum -a 256 -c SHA256SUMS.txt`.

Идентичный файл доступен в
[GitHub Release v0.1.1-unsigned](https://github.com/Slipcast-dev/MacAssistant/releases/tag/v0.1.1-unsigned).
Установка требует подтверждения macOS и помещает приложение в `/Applications`.

В текущей среде упаковки macOS добавляет служебные AppleDouble-записи `._*`.
Целостность приложения после распаковки проверяется отдельно; перед подписанным
выпуском потребуется проверка на чистом Mac.
