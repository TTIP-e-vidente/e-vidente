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

Requisitos: Node, npm, Docker.

```sh
cd BACKEND
cp .env.example .env
npm install
npm run setup:dev   # compose + migrate + usuarios demo
npm run dev
```

### Supabase (staging / prod Postgres)

Guía completa: [`docs/SUPABASE_MIGRATION.md`](docs/SUPABASE_MIGRATION.md)

```sh
cd BACKEND
copy .env.staging.example .env.staging   # completar credenciales Supabase
npm run setup:supabase                   # schema + migración 030 RLS
npm run migrate:data-to-supabase:dry-run # opcional: preview datos local → remoto
npm run smoke:api:staging
npm run dev:staging                      # backend contra Supabase (.env.staging)
```

Arquitectura: Godot → Express (JWT propio) → Postgres Supabase. **No** usamos Supabase Auth.

`.env` no se commitea. Valores base en `.env.example` (`POSTGRES_*`, `BACKEND_PORT=3000`, `JWT_*`).

**Demo:** `agus` / `123`, `margo` / `123`

**Postgres (DataGrip):** host `localhost`, port según `POSTGRES_PORT` en `.env` (default `5433`), db `evidente_dev`, user `evidente_user`, pass en `.env`.

```sh
docker exec -it e-vidente-postgres psql -U evidente_user -d evidente_dev -c "SELECT current_database();"
```

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

### `setup:dev` se queda en "Esperando PostgreSQL..."

En Windows suele pasar si ya tenés **Postgres instalado localmente** en el puerto `5432`. El script conecta a ese servicio en lugar del contenedor Docker y falla la autenticación de `evidente_user`.

**Solución:** en `.env` usá `POSTGRES_PORT=5433` (valor por defecto en `.env.example`), reiniciá el contenedor y volvé a correr el setup:

```sh
docker compose down
docker compose up -d
npm run setup:dev
```

**Alternativa:** parar el servicio Postgres local (`Get-Service *postgres*`) y dejar `POSTGRES_PORT=5432`.

Verificar qué ocupa el puerto:

```powershell
netstat -ano | findstr ":5432"
Get-Process -Id <PID>
```

## Cuidado

- `docker compose down -v` borra la DB local.
- No `DROP TABLE` sin backup.
- No cambiar endpoints/contratos sin revisar Godot.
- No commitear `.env`, `node_modules`, `dist`, volúmenes Postgres.
