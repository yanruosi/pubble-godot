#!/usr/bin/env python3
"""Remove #region agent log blocks and debug log helpers from .gd files."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def clean_content(content: str) -> str:
    # Multiline #region agent log ... #endregion (tab or no tab)
    content = re.sub(
        r"^[ \t]*#region agent log\s*\n.*?\n[ \t]*#endregion\s*\n",
        "",
        content,
        flags=re.MULTILINE | re.DOTALL,
    )
    # Trailing debug helper blocks (const + func before class or EOF)
    content = re.sub(
        r"\n#region agent log\nconst DEBUG_LOG_PATH.*?\n#endregion\n",
        "\n",
        content,
        flags=re.DOTALL,
    )
    content = re.sub(
        r"\nconst (?:DEBUG|PAN|AGENT|AGENT_DEBUG|PAN_DEBUG)_[A-Z_]+ := [^\n]+\n",
        "\n",
        content,
    )
    return content


def main() -> None:
    changed: list[str] = []
    for path in ROOT.rglob("*.gd"):
        if "debug_session_log" in path.name:
            continue
        text = path.read_text(encoding="utf-8")
        new_text = clean_content(text)
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            changed.append(str(path.relative_to(ROOT)))
    print(f"Cleaned {len(changed)} files")
    for p in changed:
        print(f"  {p}")


if __name__ == "__main__":
    main()
