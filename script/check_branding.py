"""Запрещает возврат прежнего публичного названия в тексты проекта.

Технические идентификаторы без пробелов сохраняются для совместимости данных,
SwiftPM и MCP. История коммитов не переписывается.
"""

import re
from pathlib import Path
import subprocess


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    names = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=root, check=True, capture_output=True,
    ).stdout.decode().split("\0")
    # Ищем публичную форму названия, не затрагивая стабильные API-идентификаторы.
    forbidden = re.compile(r"\bmac[\s_]+assistant\b|мак[\s_-]*ассистант", re.IGNORECASE)
    errors = 0
    for name in sorted(set(names)):
        path = root / name
        if not path.is_file() or (path.suffix not in {".md", ".swift", ".sh", ".py", ".toml", ".yml"} and path.name != "LICENSE"):
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if forbidden.search(line):
                print(f"Устаревшее публичное название: {name}:{number}")
                errors += 1
    print(f"Проверка публичного имени Athena: ошибок {errors}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
