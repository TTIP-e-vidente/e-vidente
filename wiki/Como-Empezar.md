# Cómo empezar

## Requisitos

Godot 4.6 · Git · Node 20 · proyecto Supabase (staging)

## Juego

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
```

Importar `juego/project.godot` → F5. No hace falta backend.

## Backend (Supabase Edge — sin Express para jugar online)

```bash
cd BACKEND
npm install
npm run configure:supabase-keys   # primera vez: keys en .env.supabase-keys.local
npm run integrate:staging         # migrate + deploy Edge + cron + Godot + smokes
```

Godot → F5. **No hace falta** `npm run dev`.

Guía: [BACKEND/docs/SUPABASE_QUICKSTART.md](../BACKEND/docs/SUPABASE_QUICKSTART.md)

Verificación: `npm run integrate:status` · integral: `npm run verify:integration:full`

## Carpetas útiles

`juego/interface` · `juego/contenido` · `juego/mapas` · `juego/sistemas/contenido` · `BACKEND` · `wiki`

## Smoke local

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

## PR

Rama → commit → push → PR. Trazabilidad: [Bitacora-Entrega-4](Bitacora-Entrega-4). Índice: [Bitacora](Bitacora). Checks: [CI](CI).

**Problemas:** no importa → existe `juego/project.godot`; borrar `juego/.godot/` y reimportar. Recursos rotos → Reimport All. Docs en CI → `wiki/Bitacora*.md`.
