# Estado actual

Referencia única del repo (jun 2026). Si [Entrega 1](wiki/Entrega-1.md) u otra wiki contradice esto, manda este archivo.

**Qué es:** Godot 4.6, track celiaquía por JSON, save local; backend Node+Postgres opcional para cuenta y sync.

## Hecho

- Mapa y contenido celiaquía (`juego/contenido/mapa/`, catálogo `items_celiaquia.json`)
- Modalidades: drag, quiz, match, completar palabra
- Score, estrellas, racha; save local sin login (`SaveManager`)
- API local: registro, login JWT, perfil, progreso (`BACKEND/`)
- Sync al terminar partida si hay sesión (`ProgressSyncService`)
- CI: estructura, lint, smoke Godot

## Parcial

- Tests Godot (smoke + pocos unitarios)
- Sync: funciona; poca señal en UI
- Vegan / keto / mixto: libros en UI; pack JSON solo celiaquía

## Pendiente

- Leaderboard, logros como sistema
- Refresh token, admin, mails reales
- Validar JSON de contenido en CI

## Repo

| Carpeta | Uso |
|---------|-----|
| `juego/` | Cliente Godot |
| `juego/contenido/` | JSON celiaquía — [README](juego/contenido/README.md) |
| `BACKEND/` | API — [README](BACKEND/README.md) |
| `wiki/` | Docs equipo + entregas TTIP |

## Correr

**Solo juego:** Godot 4.6 → `juego/project.godot` → F5.

**Con backend:**
```sh
cd BACKEND && cp .env.example .env && docker compose up -d
npm install && npm run setup:dev && npm run dev
```
URL del API: ver `BACKEND/README.md`.

## Flujo celiaquía (código)

`MapScene` → `CargadorDeMapa` → `ArmadorDePartida` → `NodeContentLoader` → `ActivityAdapter` → minijuego → `ContinuidadDePartidaDeNodo` → `SaveManager` (+ sync si hay sesión).

Legacy: no sumar contenido en `contenido/backup/`, `DragDropNode.tscn`, rutas viejas de `CargadorDeContenidoDeNodo`. Flujo de demo congelado: [juego/README.md](juego/README.md).

## Más docs

- Arranque: [wiki/Como-Empezar.md](wiki/Como-Empezar.md)
- Arquitectura: [wiki/Arquitectura-General.md](wiki/Arquitectura-General.md)
- Contenido JSON: [juego/contenido/README.md](juego/contenido/README.md)
- API: [BACKEND/README.md](BACKEND/README.md)
- Tests: [juego/tests/README.md](juego/tests/README.md)
- CI: [wiki/CI.md](wiki/CI.md)
- Bitácora: [wiki/Bitacora.md](wiki/Bitacora.md) → [E3](wiki/Bitacora-Entrega-3.md) (activa), [E2](wiki/Bitacora-Entrega-2.md), …
