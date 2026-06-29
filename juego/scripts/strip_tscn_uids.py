#!/usr/bin/env python3
"""Remove stale uid attributes from Godot .tscn ext_resource lines."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UID_PATTERN = re.compile(r' uid="uid://[^"]+"')


def main() -> None:
    count_files = 0
    count_repl = 0
    for path in ROOT.rglob("*.tscn"):
        text = path.read_text(encoding="utf-8")
        new_text, replacements = UID_PATTERN.subn("", text)
        if replacements:
            path.write_text(new_text, encoding="utf-8")
            count_files += 1
            count_repl += replacements
    print(f"Stripped {count_repl} uid attrs from {count_files} .tscn files")


if __name__ == "__main__":
    main()
