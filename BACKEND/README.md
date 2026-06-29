# Backend

Guía: [SUPABASE_QUICKSTART.md](docs/SUPABASE_QUICKSTART.md) · Verificación: `npm run verify:integration:full`

**API online:** Supabase Edge Functions (Deno). **Express** queda como legacy para tests Node — [docs/EXPRESS_LEGACY.md](docs/EXPRESS_LEGACY.md).

Godot guarda local primero; si hay sesión, sincroniza al cerrar partida. Sin API, el juego sigue.

**Godot (producción):** `BackendSession.gd` → `BackendApiClient.gd` → **Edge Functions** → Postgres/Storage.  
**Save local:** `SaveManager.gd` (no se reemplaza).

## MER → tablas

| MER | Módulo | Tabla |
|-----|--------|-------|
| USER | auth + user | `users` |
| IMAGE | image | `images` |
| PROFILE | profile | `profiles` (`streak_id` → `streaks`) |
| STREAK | streak | `streaks` |
| PROGRESO_RESTRICCION | progreso-restriccion | `progress_restrictions` |
| HISTORY_GAME | history-game | `history_games` (nodo del mapa: completado, precision) |
| GAME | game | `games` (cada partida jugada) |

Notas: `password_hash` (bcrypt), nunca password en claro. `client_run_id` idempotente en `games`. Migración `008_align_excalidraw_canonical.sql` unificó el esquema.

## Código

`BACKEND/src/modules/` — `auth`, `health`, `user`, `image`, `profile`, `streak`, `progreso-restriccion`, `history-game`, `game`.

Capas: `route → controller → service → repository → mapper`. Sin SQL en controllers; sin `password_hash` en respuestas.

## Levantar (jugar online — sin Express)

Requisitos: Node 20, proyecto Supabase (staging), keys en `.env.supabase-keys.local`.

**Guía rápida:** [`docs/SUPABASE_QUICKSTART.md`](docs/SUPABASE_QUICKSTART.md)  
**Guía rápida:** [`docs/SUPABASE_QUICKSTART.md`](docs/SUPABASE_QUICKSTART.md)  
**Express legacy:** [`docs/EXPRESS_LEGACY.md`](docs/EXPRESS_LEGACY.md)

```sh
cd BACKEND
npm install
npm run configure:supabase-keys    # primera vez
npm run integrate:staging          # migrate + deploy + cron + godot + smokes Edge
```

Godot → F5. **No** hace falta `npm run dev`.

| Comando | Para qué |
|---------|----------|
| `npm run integrate:staging` | Setup completo staging (recomendado) |
| `npm run integrate:status` | Panel DB + Edge + cron + Godot |
| `npm run verify:integration:full` | **Verificación integral** (~3 min, recomendado) |
| `npm run smoke:edge:staging` | Smokes auth/progress/avatar/leaderboard |
| `npm run smoke:brevo-edge` | Brevo + verify-email-health |
| `npm run smoke:verify-email-edge` | OTP vía Edge (register + request) |
| `npm run check:edge:staging` | Health Edge Functions |
| `npm run sync:godot-config:staging` | Solo actualizar `backend.local.json` |
| `npm run dev` | **Legacy:** Express local :3010 (solo portar lógica Node) |

**Arquitectura:** Godot → **Edge Functions** (JWT propio) → Postgres Supabase + Storage. Mails → Edge + Brevo + `pg_cron`.

`.env.staging` / `.env.supabase-keys.local` no se commitean.

Migraciones: `BACKEND/migrations/`, `npm run migrate`. No editar migraciones viejas; agregar archivo nuevo.

## API (Edge Functions)

En staging/producción el cliente Godot llama a `https://<ref>.supabase.co/functions/v1/<nombre>`.

| Grupo | Edge Function(s) |
|-------|------------------|
| Auth | `auth-register`, `auth-login`, `auth-me`, `auth-health` |
| Perfil | `player-me` (GET/PATCH) |
| Progreso | `player-progress-get`, `player-progress-save`, `player-progress-batch`, `player-progress-reset` |
| Avatar | `avatar-upload`, `avatar-get`, `avatar-delete`, `avatar-public` |
| Ranking | `leaderboard-list`, `leaderboard-meta`, `leaderboard-me`, `leaderboard-me-summary` |
| Verify mail | `verify-email-request`, `verify-email-confirm`, `verify-email-health` |
| Jobs (cron) | `internal-job` (`X-Job-Secret`) |

Contrato Express legacy (solo tests Node): ver [EXPRESS_LEGACY.md](docs/EXPRESS_LEGACY.md).

### POST `/player/me/progress` (contrato Godot)

Campos usados por el cliente: `clientRunId`, `restriction`, `expToAdd`, `nodeId`, `gameType`, `accuracy`, `completed`, `score`, `correctAnswers`, `wrongAnswers`, `durationSeconds`. No cambiar nombres sin actualizar `RunSummaryBuilder` / `BackendApiClient`.

## Probar (staging)

```sh
npm run verify:integration:full   # integral: panel + Edge + Brevo + OTP + crons + schema
npm run integrate:status            # panel rápido
npm run smoke:edge:staging
```

Inbox real (opcional):

```sh
SMOKE_EMAIL_TO=tu@mail.com npm run smoke:verify-email-edge -- --send
```

Tests Node (Express legacy, solo desarrollo de módulos):

```sh
npm run build && npm test
npm run dev          # Express :3010
npm run smoke:api    # contra Express local
```

## Fuera de alcance (por ahora)

Refresh tokens, admin panel, Supabase Auth nativo (Fase 7 opcional).

## Emails (Brevo vía Edge)

Documentación: [wiki/Entrega-4-Guia-Rapida.md](../wiki/Entrega-4-Guia-Rapida.md) · [docs/BREVO_SETUP.md](docs/BREVO_SETUP.md) · [docs/SUPABASE_EDGE_FUNCTIONS.md](docs/SUPABASE_EDGE_FUNCTIONS.md)

En staging/producción los mails salen desde **Edge Functions** + secrets Supabase (no Express).

- **5 templates:** OTP, bienvenida, racha en riesgo, racha perdida, cambio mail
- **OTP:** `verify-email-request` → Brevo; bienvenida tras confirmar
- **Crons (pg_cron → `internal-job`):** racha 18:00 y 00:00 ART; retry 08:00 y 20:00 ART
- **Auditoría:** tabla `email_deliveries`
- **Verificación:** `npm run smoke:brevo-edge` · `npm run smoke:verify-email-edge` · `npm run verify:integration:full`

Módulo Express en `src/modules/email/` — legacy para tests Node (`validate:email-flow` local).

## Problemas frecuentes

### No conecta a Supabase

```sh
npm run supabase:diagnose
npm run integrate:status
```

Revisá `BACKEND/.env.staging` (`POSTGRES_SSL=true`, password entre comillas si tiene `#`) y `BACKEND/.env.supabase-keys.local`.

## Cuidado

- No `DROP TABLE` sin backup.
- No cambiar endpoints/contratos sin revisar Godot.
- No commitear `.env`, `node_modules`, `dist`, volúmenes Postgres.
