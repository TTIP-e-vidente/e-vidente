#!/usr/bin/env python3
"""Repara subcadenas rotas por reemplazo read→leer y similares. Excluye addons/."""
from __future__ import annotations

import sys
from pathlib import Path

SKIP_PARTS = {"addons"}

FIXES: list[tuple[str, str]] = [
    ("@onleery", "@onready"),
    ("func _leery(", "func _ready("),
    ("func _leery() ->", "func _ready() ->"),
    ("func _leery():", "func _ready():"),
    ("func _leery\n", "func _ready\n"),
    ("super._leery()", "super._ready()"),
    ("is_node_leery(", "is_node_ready("),
    ("load_thleered_get_status", "load_threaded_get_status"),
    ("load_thleered_get(", "load_threaded_get("),
    ("alleery_connected", "already_connected"),
    ("_alleery_finished", "_already_finished"),
    ("alleery_played_today", "already_played_today"),
    ("username alleery exists", "username already exists"),
    ("mail alleery exists", "mail already exists"),
    ("cambiar_escena_to_file", "change_scene_to_file"),
    ("_animar_vinculo_cleero", "_animar_vinculo_correcto"),
    ("cleero_por", "creado_por"),
    ("renderizarizar", "renderizar"),
    ("_renderizarizar", "_renderizar"),
    (" en su _leery()", " en su _ready()"),
    ("via _leery()", "via _ready()"),
    ("autoconfigura en _leery()", "autoconfigura en _ready()"),
]


def should_skip(path: Path) -> bool:
    return any(part in SKIP_PARTS for part in path.parts)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    changed = 0
    for path in list(root.rglob("*.gd")) + list(root.rglob("*.tscn")):
        if should_skip(path):
            continue
        text = path.read_text(encoding="utf-8")
        original = text
        for old, new in FIXES:
            text = text.replace(old, new)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed += 1
    print(f"Reparados: {changed} archivos (sin addons/)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
