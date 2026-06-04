#!/usr/bin/env python3
"""Repara strings con mojibake (UTF-8 leido como Latin-1) en JSON del juego."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def fix_string(value: str) -> str:
	if "Ã" not in value and "â" not in value:
		return value
	try:
		return value.encode("latin-1").decode("utf-8")
	except (UnicodeDecodeError, UnicodeEncodeError):
		return value


def fix_value(value):
	if isinstance(value, str):
		return fix_string(value)
	if isinstance(value, list):
		return [fix_value(item) for item in value]
	if isinstance(value, dict):
		return {key: fix_value(item) for key, item in value.items()}
	return value


def fix_file(path: Path) -> bool:
	raw = path.read_text(encoding="utf-8-sig")
	if "Ã" not in raw and "â" not in raw:
		return False
	data = json.loads(raw)
	fixed = fix_value(data)
	path.write_text(
		json.dumps(fixed, ensure_ascii=False, indent="\t") + "\n",
		encoding="utf-8",
	)
	return True


def main() -> int:
	root = Path(__file__).resolve().parents[1]
	changed: list[Path] = []
	for path in sorted(root.rglob("*.json")):
		if fix_file(path):
			changed.append(path)
	for path in changed:
		print(f"fixed: {path.relative_to(root.parent)}")
	print(f"total: {len(changed)} file(s)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
