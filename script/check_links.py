"""Проверка ссылок документации без сторонних зависимостей.

Локальные ссылки и Markdown-якоря проверяются всегда. --external дополнительно
проверяет HTTP-адреса; этот режим запускается после публикации новых релизов.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import re
import subprocess
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent.parent


def anchors(path: Path) -> set[str]:
    """Повторяем slug заголовков GitHub, сохраняя кириллицу и повторные ID."""
    result: set[str] = set()
    counts: dict[str, int] = {}
    for line in visible_text(path).splitlines():
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*$", line)
        if match:
            slug = re.sub(r"[^\w\- ]", "", match[1].lower()).replace(" ", "-")
            count = counts.get(slug, 0)
            counts[slug] = count + 1
            result.add(f"{slug}-{count}" if count else slug)
    return result


def visible_text(path: Path) -> str:
    """Не считаем примеры внутри fenced code реальными ссылками страницы."""
    return re.sub(r"```[^\n]*\n.*?```", "", path.read_text(encoding="utf-8"), flags=re.S)


def destinations(path: Path) -> list[str]:
    text = visible_text(path)
    # Inline Markdown, HTML src/href и автоссылки <https://...>.
    matches = re.findall(r"\]\(\s*([^\s)]+)(?:\s+[^)]*)?\)", text)
    matches += re.findall(r'(?:src|href)=["\']([^"\']+)["\']', text)
    matches += re.findall(r"<(https?://[^>\s]+)>", text)
    matches += re.findall(r"https?://[^\s<>\x22\x27\x60)]+", text)
    return [value.strip("<>") for value in matches]


def check_external(url: str) -> tuple[str, str | None]:
    """HEAD экономит трафик; GET используется для сайтов, запрещающих HEAD."""
    for method in ["HEAD", "GET"]:
        try:
            request = Request(url, method=method, headers={"User-Agent": "Athena-Link-Check/1.0"})
            with urlopen(request, timeout=20) as response:
                if response.status >= 400:
                    return url, f"HTTP {response.status}"
                return url, None
        except HTTPError as error:
            if method == "HEAD" and error.code in [403, 405, 501]:
                continue
            return url, f"HTTP {error.code}"
        except (URLError, TimeoutError, OSError) as error:
            return url, str(error)
    return url, "Не удалось проверить"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--external", action="store_true")
    arguments = parser.parse_args()
    # Читаем только файлы проекта, без .build, dist и пользовательских данных.
    listed = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=ROOT, check=True, capture_output=True,
    ).stdout.decode().split("\0")
    documents = sorted({ROOT / name for name in listed if name.endswith(".md") and (ROOT / name).is_file()})
    errors: list[str] = []
    external: set[str] = set()
    local_count = 0
    for document in documents:
        for destination in destinations(document):
            parts = urlsplit(destination)
            if parts.scheme in ["http", "https"]:
                external.add(destination)
                continue
            if parts.scheme:
                continue
            local_count += 1
            target = (document.parent / unquote(parts.path)).resolve() if parts.path else document
            if not target.exists():
                errors.append(f"{document.relative_to(ROOT)}: отсутствует {destination}")
            elif parts.fragment and target.suffix == ".md" and unquote(parts.fragment) not in anchors(target):
                errors.append(f"{document.relative_to(ROOT)}: отсутствует якорь {destination}")
    if arguments.external:
        with ThreadPoolExecutor(max_workers=4) as pool:
            for url, error in pool.map(check_external, sorted(external)):
                if error:
                    errors.append(f"{url}: {error}")
    for error in errors:
        print(error)
    print(f"Документов: {len(documents)}; локальных ссылок: {local_count}; HTTP-ссылок: {len(external)}; ошибок: {len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
