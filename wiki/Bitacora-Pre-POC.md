# Bitácora — Antes del POC

[← Índice](Bitacora) · **Mar 2026** · Reconstruido desde `git log` (commits `8f456f5` → `2dd6754`).

Arranque del monorepo TTIP: repo nuevo, herencia del proyecto anterior, wiki y primeros guardrails de CI. Todavía sin gameplay documentado en esta bitácora.

Más nuevo arriba.

---

### `2026-03-31` — Wiki, bitácora y CI inicial
<kbd>Docs</kbd> <kbd>CI</kbd>

**Qué se hizo**
- Estructura wiki + script de publicación.
- Guardrails: estructura de carpetas, ESLint si aplica, presencia de documentación.
- Bitácora y Getting Started en wiki; simplificación de workflows (sin GitHub Pages).

**Evidencia**
- `1a6ad9b`, `6d3a298`, `3db49f0`, `9d2768a`, `80122db`
- `wiki/`, `.github/workflows/`, `scripts/ci/`

---

### `2026-03-29` — Continuidad desde el repo anterior
<kbd>Repo</kbd>

**Qué problema resolvió**
- No empezar de cero: migrar trabajo previo de e-vidente al repo del curso.

**Qué se hizo**
- Clone/import del repositorio viejo (`Cloned the old repository e-vidente`).
- Base del proyecto Godot y assets heredados.

**Evidencia**
- `9db6df2`

---

### `2026-03-28` — Repositorio y licencia
<kbd>Repo</kbd>

**Qué se hizo**
- Initial commit, MIT License, primer README.

**Evidencia**
- `8f456f5`, `1ee6431`, `1f6dbf5`
