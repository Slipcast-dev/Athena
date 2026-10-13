# Подготовка релиза

## Подтверждённый локальный процесс

`./script/build_and_run.sh --package` создаёт оптимизированный
`dist/MacAssistant.app`, проверяет синтаксис `Info.plist` и целостность ad-hoc
подписи через `codesign --verify --deep --strict`.

`./script/build_and_run.sh --installer` дополнительно создаёт
`dist/MacAssistant-0.1.0-unsigned.pkg`. Он устанавливает `MacAssistant.app` в
`/Applications` и содержит MCP-исполнитель внутри bundle. Пакет unsigned и
предназначен только для локальной проверки до появления сертификата Developer ID.

## Что ещё нужно для внешнего распространения

В репозитории нет Apple Developer Team ID, сертификата Developer ID Application
или учётных данных notarization. Поэтому нельзя честно заявлять, что приложение
готово к распространению вне данного Mac. Перед внешним выпуском владелец должен:

1. Подписать главный бинарник и все вложенные исполняемые компоненты сертификатом
   Developer ID Application, включив hardened runtime.
2. Проверить entitlements после подписи.
3. Отправить архив Apple на notarization и дождаться результата.
4. Прикрепить notarization ticket к `.app` и проверить его на чистой системе.

Ad-hoc подпись в сценарии предназначена только для локальной технической
проверки и не заменяет ни один из этих шагов.
