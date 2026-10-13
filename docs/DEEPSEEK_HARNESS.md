# DeepSeek Harness: локальный MCP-мост

## Назначение

`MacAssistantMCP` — отдельный исполняемый процесс для подключения DeepSeek
Harness по стандартному вводу-выводу. Выбран `stdio`: официальный клиент Harness
рекомендует этот транспорт для локальной программы. Процесс не открывает порт и
не имеет командной оболочки.

## Разрешённые операции

| MCP-инструмент | Результат | Разрешение |
| --- | --- | --- |
| `system.get_info` | Модель, версия macOS, архитектура и ядра; без серийного номера | Только чтение |
| `system.get_metrics` | CPU, RAM и свободное место | Только чтение |
| `diagnostics.run` | Локальные выводы диагностики | Только чтение |
| `storage.get_overview` | Общий и доступный объём диска | Только чтение |

Мост отклоняет любые другие имена инструментов. Он не принимает пути, команды
shell, AppleScript, API-ключи или текст для отправки в сеть. Сканирование файлов,
изменение настроек, удаление файлов и вызовы ИИ не включены: для них потребуется
отдельный блок с пользовательским согласием и аудитом.

## Сборка и проверка

Из корня проекта:

```zsh
swift build
swift run MacAssistantMCP
```

В рабочем окружении Harness следует указать команду собранного бинарного файла
`.build/debug/MacAssistantMCP`. При разработке вместо него допустима команда
`swift run --package-path /Users/Aleksandr/Documents/Проекты/MacAssistant MacAssistantMCP`.
Параметр `serverName` в конфигурации Harness должен быть `mac-assistant`:
Harness публикует его инструменты под пространством имён `mcp__mac-assistant__…`.

## Проверка границ

Полный набор XCTest проверяет allowlist и отказ `shell.execute`. Ручная
протокольная проверка посылает `initialize`, `tools/list` и запрещённый
`tools/call`; последний возвращает MCP-результат с `isError: true`, не исполняя
никакого внешнего процесса.

## Официальные первоисточники

- DeepSeek Harness: <https://www.deepseek.com/harness/en/>
- Репозиторий Harness: <https://github.com/deepseek-ai/deepseek-harness>
- Документация MCP-клиента Harness: <https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/mcp/mcp-client/README.md>
