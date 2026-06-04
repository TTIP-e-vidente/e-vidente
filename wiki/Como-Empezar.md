# Cómo empezar

Estado: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md)

## Requisitos

Godot 4.6 · Git · (opcional) Node 20 + Docker para `BACKEND/`

## Juego

```bash
git clone https://github.com/TTIP-e-vidente/e-vidente.git
cd e-vidente
```

Importar `juego/project.godot` → F5. No hace falta backend.

## Backend

```bash
cd BACKEND
cp .env.example .env
docker compose up -d
npm install && npm run setup:dev && npm run dev
```

URL en Godot: `BACKEND/README.md`. Probar: `npm run build && npm test` y con server up `npm run smoke:api`.

## Carpetas útiles

`juego/interface` · `juego/contenido` · `juego/mapas` · `juego/sistemas/contenido` · `BACKEND` · `wiki`

## Smoke local

```bash
godot --headless --path juego -s res://tests/vertical_slice_smoke_test.gd
```

## PR

Rama → commit → push → PR. Trazabilidad: [Bitacora-Entrega-3](Bitacora-Entrega-3). Índice: [Bitacora](Bitacora). Checks: [CI](CI).

**Problemas:** no importa → existe `juego/project.godot`; borrar `juego/.godot/` y reimportar. Recursos rotos → Reimport All. Docs en CI → `wiki/Bitacora*.md` o ESTADO-ACTUAL.
