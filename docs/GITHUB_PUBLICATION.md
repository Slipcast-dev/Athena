# Публикация на GitHub

## Текущая публикация

Исходный код опубликован в
[Slipcast-dev/MacAssistant](https://github.com/Slipcast-dev/MacAssistant).
Репозиторий публичный, его ветка по умолчанию — `main`; добавлены темы `macos`,
`swift`, `swiftui`, `mcp`, `ai`, `diagnostics`, `deepseek`, `codex` и
`apple-silicon`.

## Для новой копии репозитория

1. Создайте пустой репозиторий GitHub без автоматически сгенерированных файлов.
2. Проверьте, что `git status` чист и `swift test` успешен.
   Также проверьте `./script/build_and_run.sh --package` для локальной
   технической валидации релизного bundle.
3. Добавьте удалённый репозиторий и отправьте `main` вместе с тегами:

```zsh
git remote add origin <URL-вашего-репозитория>
git push -u origin main
git push --tags
```

## Что уже подготовлено

- `.github/workflows/ci.yml` проверяет XCTest, debug/release-сборку и типовые
  секреты на macOS runner.
- `.github/ISSUE_TEMPLATE/bug_report.md` помогает собрать воспроизводимые баги
  без публикации личных данных.
- `CONTRIBUTING.md` фиксирует правила безопасного вклада.
- `.gitignore` исключает локальные сборки, IDE-настройки, `.env`-файлы и
  отладочные артефакты из истории Git.
- `CODE_OF_CONDUCT.md`, `SECURITY.md` и шаблон pull request закрывают основные
  требования Community Profile GitHub.

## Перед GitHub Release

Используйте только подписанный и notarized `.pkg`. Локальный
`MacAssistant-0.1.0-unsigned.pkg` предназначен для тестирования и не должен
прикрепляться к публичному релизу.
