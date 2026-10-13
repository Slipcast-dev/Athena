#!/usr/bin/env bash
# Регистрирует локальный MCP-исполнитель в Codex либо печатает безопасный
# фрагмент для DeepSeek Harness. Скрипт не редактирует Harness-конфигурацию сам.
set -euo pipefail

MODE="${1:-}"
APP_PATH="${2:-/Applications/MacAssistant.app}"
MCP_BINARY="$APP_PATH/Contents/MacOS/MacAssistantMCP"

if [[ ! -x "$MCP_BINARY" ]]; then
  echo "MCP-исполнитель не найден: $MCP_BINARY" >&2
  echo "Сначала установите MacAssistant.app или передайте путь вторым аргументом." >&2
  exit 1
fi

case "$MODE" in
  --codex)
    # Удаляем только одноимённую предыдущую конфигурацию; иные MCP-серверы Codex
    # не затрагиваются. Затем используем официальный CLI вместо ручного TOML.
    codex mcp remove mac-assistant >/dev/null 2>&1 || true
    codex mcp add mac-assistant -- "$MCP_BINARY"
    codex mcp get mac-assistant --json
    ;;
  --harness-config)
    # Пользователь вставляет блок в доверенный Cordis profile patch после обзора.
    # Путь передаётся YAML как строка и не интерполетируется через shell Harness.
    cat <<EOF
- id: mcp-mac-assistant
  name: '@deepseek-ai/dsh-mcp-client'
  config:
    serverName: mac-assistant
    transport: stdio
    command: '$MCP_BINARY'
    args: []
    env: {}
    cwd: '$(dirname "$MCP_BINARY")'
    toolCallTimeoutMs: 60000
    failOnStartupError: true
EOF
    ;;
  *)
    echo "usage: $0 --codex|--harness-config [путь-к-MacAssistant.app]" >&2
    exit 2
    ;;
esac
