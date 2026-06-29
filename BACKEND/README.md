# Backend

Estado monorepo: [ESTADO-ACTUAL.md](../ESTADO-ACTUAL.md)

API local (Node, Express, TypeScript, PostgreSQL) para registro, login JWT, perfil y progreso. Godot guarda local primero; si hay sesión, sincroniza al cerrar partida. Sin API, el juego sigue.

**Godot:** `BackendSession.gd` → `BackendApiClient.gd` → Express → service → repository → Postgres.  
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

## Levantar

Requisitos: Node, npm, proyecto Supabase (staging).

### Desarrollo (Supabase — único camino)

**Guía rápida:** [`docs/SUPABASE_QUICKSTART.md`](docs/SUPABASE_QUICKSTART.md)  
**Stack completo (DB + deploy):** [`docs/SUPABASE_FULL_STACK.md`](docs/SUPABASE_FULL_STACK.md)

```sh
cd BACKEND
npm install
npm run supabase:init
# completar .env.staging (password, JWT, Brevo si aplica)
npm run supabase:bootstrap:apply:seed
npm run staging:verify    # status + schema + smoke API (+ email si Brevo OK)
npm run dev               # Express → Supabase + sync Godot (:3010)
```

| Comando | Para qué |
|---------|----------|
| `npm run dev` | **Default:** Supabase staging + sync Godot |
| `npm run dev:staging` | Alias de `dev` |
| `npm run integrate:status` | Panel DB + Edge + cron + Godot config |
| `npm run staging:verify` | Chequeo completo antes de demo/deploy |
| `npm run staging:verify:email` | Igual + smoke Brevo obligatorio |
| `npm run validate:email-flow:staging` | E2E mails contra Supabase |
| `npm run smoke:email:staging` | Smoke transaccional Brevo |

`dev:local` y `setup:dev` están **deshabilitados** (antes levantaban Postgres con Docker).

Deploy: `npm run build` + `npm run start:prod` · health `GET /health/ready` · blueprint `render.yaml`

**Arquitectura:** Godot → Express (JWT propio) → Postgres Supabase. Mails OTP y jobs → **Edge Functions** + Brevo + `pg_cron`. **No** usamos Supabase Auth ni Docker local.

`.env.staging` / `.env` no se commitean. Templates: `.env.staging.example`, `.env.example`.

**Demo:** `agus` / `123`, `margo` / `123`

### Postgres local (Docker) — retirado

El flujo `docker compose` + `.env` local ya no se usa en desarrollo. `docker-compose.yml` queda solo como referencia histórica o migración puntual de datos (`migrate-data-local-to-supabase.ts` si tenés un dump viejo).

Migraciones: `BACKEND/migrations/`, `npm run migrate`. No editar migraciones viejas; agregar archivo nuevo.

## Endpoints

| Grupo | Rutas |
|-------|--------|
| Auth | `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `POST /auth/logout` |
| Jugador | `GET /player/me`, `PATCH /player/me`, `GET /player/me/progress`, `POST /player/me/progress` |
| Health | `GET /health`, `GET /health/db` |
| Dev (PoC) | `POST /dev/player-progress`, `GET /dev/player-progress/:username` |

Integración real: `/player/me/progress` con Bearer token. `/dev/*` solo pruebas manuales.

### POST `/player/me/progress` (contrato Godot)

Campos usados por el cliente: `clientRunId`, `restriction`, `expToAdd`, `nodeId`, `gameType`, `accuracy`, `completed`, `score`, `correctAnswers`, `wrongAnswers`, `durationSeconds`. No cambiar nombres sin actualizar `RunSummaryBuilder` / `BackendApiClient`.

## Probar

```sh
curl http://localhost:3000/health
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"usernameOrMail":"agus","password":"123"}'
curl http://localhost:3000/player/me -H "Authorization: Bearer TOKEN"
curl -X POST http://localhost:3000/player/me/progress \
  -H "Content-Type: application/json" -H "Authorization: Bearer TOKEN" \
  -d '{"clientRunId":"run_demo_1","restriction":"CELIAQUIA","expToAdd":10,"nodeId":"demo_node_1","gameType":"quiz","accuracy":90,"completed":true,"score":100,"correctAnswers":8,"wrongAnswers":2,"durationSeconds":60}'
```

```sh
npm run build && npm test
npm run smoke:api   # con server up
```

## Fuera de alcance

Refresh tokens, admin, leaderboard online, rename destructivo de tablas.

## Emails (Brevo)

Documentación completa: [wiki/Entrega-4-Guia-Rapida.md](../wiki/Entrega-4-Guia-Rapida.md) · Setup: [`docs/BREVO_SETUP.md`](docs/BREVO_SETUP.md)

Módulo en `src/modules/email/` — **5 templates** (OTP, bienvenida, 2 rachas, cambio mail). Por defecto `EMAIL_ENABLED=false`.

- Verificación OTP → bienvenida **tras** confirmar (no al registro).
- Cron 19:00 ART: `npm run email:streaks` o `POST /internal/jobs/streak-emails` (`X-Job-Secret`).
- Reintento: `npm run email:retry-failed` · Cron cloud: `.github/workflows/email-cron.yml`.
- Consentimiento racha: `email_notifications_enabled` (registro + `PATCH /player/me`).
- Auditoría: `email_deliveries` (`pending` | `sent` | `failed` | `skipped`).
- Validación E2E: `npm run validate:email-flow` · Detalle: `src/modules/email/README.md`.
- Dev: `GET /dev/email/templates` · `/preview` · `/deliveries`.

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
