# Estado actual

## Hecho

- Mapa y contenido celiaquía (`juego/contenido/mapa/`, catálogo `items_celiaquia.json`)
- Modalidades: drag, quiz, match, completar palabra, enseñanza
- Score, estrellas, racha; save local sin login (`SaveManager`)
- API local: registro, login JWT, perfil, progreso (`BACKEND/`)
- Sync al terminar partida si hay sesión (`ProgressSyncService`)
- CI: estructura, lint, smoke Godot

## Parcial

- Tests Godot (smoke + pocos unitarios)
- Sync
- Vegan / keto / mixto: libros en UI; pack JSON solo celiaquía

## Entrega 4 (emails) — lista para revisión

- **Entrada recomendada:** [wiki/Entrega-4-Guia-Rapida.md](wiki/Entrega-4-Guia-Rapida.md) (5 min)
- **Código:** 5 templates, OTP, jobs, dedupe, UI Godot — listo
- **Docs:** 10 páginas en `wiki/Entrega-4*.md` + bitácora
- **Tests:** `npm run test:email` ✅ (2026-06-25, 5/5 con Brevo) · `validate:email-flow` ✅
- **Evidencia visual:** capturas bandeja — [checklist](wiki/Entrega-4-Evidencia.md)
- **Producción:** deploy + dominio — pendiente

## Pendiente

- Leaderboard, logros como sistema
- Refresh token, admin
- Activación mails en producción

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

## Flujo celiaquía

`MapScene` → `CargadorDeMapa` → `ArmadorDePartida` → `NodeContentLoader` → `ActivityAdapter` → partida con mini juegos → `ContinuidadDePartidaDeNodo` → `SaveManager` (+ sync si hay sesión).


## Más docs

- Arranque: [wiki/Como-Empezar.md](wiki/Como-Empezar.md)
- Arquitectura: [wiki/Arquitectura-General.md](wiki/Arquitectura-General.md)
- Contenido JSON: [juego/contenido/README.md](juego/contenido/README.md)
- API: [BACKEND/README.md](BACKEND/README.md)
- Tests: [juego/tests/README.md](juego/tests/README.md)
- CI: [wiki/CI.md](wiki/CI.md)
- Bitácora: [wiki/Bitacora.md](wiki/Bitacora.md) → [E4](wiki/Bitacora-Entrega-4.md) (activa), [E3](wiki/Bitacora-Entrega-3.md), …
