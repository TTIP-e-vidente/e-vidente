# Cómo empezar

Estado: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md)

## Requisitos

Godot 4.6 · Git · Node 20 · proyecto Supabase (staging)

## Juego

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
```

Importar `juego/project.godot` → F5. No hace falta backend.

## Backend (Supabase)

```bash
cd BACKEND
npm install
npm run supabase:init      # primera vez: completar .env.staging
npm run dev                # Express → Supabase + sync Godot
```

Guía: [BACKEND/docs/SUPABASE_QUICKSTART.md](../BACKEND/docs/SUPABASE_QUICKSTART.md) · Verificación: `npm run integrate:status`

## Carpetas útiles

`juego/interface` · `juego/contenido` · `juego/mapas` · `juego/sistemas/contenido` · `BACKEND` · `wiki`

## Smoke local

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

## PR

Rama → commit → push → PR. Trazabilidad: [Bitacora-Entrega-4](Bitacora-Entrega-4). Índice: [Bitacora](Bitacora). Checks: [CI](CI).

**Problemas:** no importa → existe `juego/project.godot`; borrar `juego/.godot/` y reimportar. Recursos rotos → Reimport All. Docs en CI → `wiki/Bitacora*.md` o ESTADO-ACTUAL.
