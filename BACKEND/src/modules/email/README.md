# Módulo de emails (Brevo)

Envío transaccional con auditoría en PostgreSQL. Los templates viven en `templates/` y se versionan en git.

## Estructura

```
email/
├── templates/
│   ├── layout.ts                 # HTML base, escape, footer
│   ├── welcome.template.ts
│   ├── streak-at-risk.template.ts
│   ├── streak-lost.template.ts
│   ├── types.ts
│   └── index.ts                  # registry + preview
├── email.service.ts              # orquestación
├── email.repository.ts           # DB + candidatos racha
├── email.client.ts               # API Brevo
├── email.config.ts
└── email.routes.ts               # endpoints dev
```

## Templates disponibles

| `template_key`   | Cuándo se envía                         | Consentimiento requerido |
|------------------|-----------------------------------------|--------------------------|
| `welcome`        | Registro exitoso con mail               | No (transaccional)       |
| `streak_at_risk` | Jugó ayer, hoy sin actividad            | Sí                       |
| `streak_lost`    | 2+ días sin actividad                   | Sí                       |

Consentimiento: `email_notifications_enabled` en `users` (registro `accept_email_notifications`, perfil `PATCH /player/me`). Config Brevo: `BACKEND/docs/BREVO_SETUP.md`.

## Variables por template

- **welcome:** `name`, `mail`
- **streak_at_risk / streak_lost:** `name`, `mail`, `streakCount`

## Auditoría (`email_deliveries`)

Estados: `pending` → `sent` | `failed`

| Campo | Descripción |
|-------|-------------|
| `recipient_email` | Destino real del intento |
| `subject` | Asunto renderizado |
| `provider_message_id` | ID de Brevo |
| `error_message` | Error si falló |
| `attempt_count` | Reintentos sobre la misma fila |
| `dedupe_key` | Evita duplicados (`welcome`, `at_risk:YYYY-MM-DD`, `lost:YYYY-MM-DD`) |

Los `pending` viejos (> `EMAIL_PENDING_STALE_MINUTES`, default 15) pasan a `failed` automáticamente.

El cron de rachas envía en paralelo con límite (`EMAIL_BATCH_CONCURRENCY`, default 5) para no saturar Brevo ni el pool de Postgres. Los candidatos ya enviados o en `pending` se filtran en SQL antes del loop.

## Configuración (`.env`)

```env
EMAIL_ENABLED=false
BREVO_API_KEY=
BREVO_SENDER_EMAIL=noreply@tudominio.com
BREVO_SENDER_NAME=E-VIDENTE
EMAIL_CRON_SECRET=change_me
EMAIL_TIMEZONE=America/Argentina/Buenos_Aires
EMAIL_PENDING_STALE_MINUTES=15
EMAIL_BATCH_CONCURRENCY=5
EMAIL_REQUEST_TIMEOUT_MS=15000
EMAIL_REQUEST_MAX_ATTEMPTS=3
EMAIL_REQUEST_RETRY_BASE_MS=500
```

## Smoke y demo local

### Validar módulo (`smoke:email`)

```bash
cd BACKEND
docker compose up -d
npm run smoke:email
```

Verifica config Brevo, genera previews de los 3 templates y lista `email_deliveries`.

Envío real de prueba (welcome):

```bash
# PowerShell
$env:SMOKE_EMAIL_TO="tu@mail.com"
npm run smoke:email -- --send
```

### Demo racha en riesgo (`seed:streak-email-demo`)

Crea/actualiza usuario `streak_demo` con racha 7 y `last_activity_day = ayer`:

```bash
npm run seed:streak-email-demo
npm run email:streaks
```

Todo en uno (seed + job):

```bash
npm run seed:streak-email-demo -- --run-job
```

Variables opcionales: `STREAK_DEMO_USERNAME`, `STREAK_DEMO_MAIL`, `STREAK_DEMO_PASSWORD`, `STREAK_DEMO_COUNT`.

## Cómo validar todo el flujo

### Capa 1 — Automatizado sin Brevo (CI / cada PR)

```bash
cd BACKEND
npm run test
npm run test:email
```

### Capa 2 — Smoke operativo

```bash
npm run smoke:email
```

### Capa 3 — Circuito real end-to-end

```bash
docker compose up -d
npm run migrate
npm run validate:email-flow
```

Opcional limpieza: `npm run validate:email-flow -- --cleanup`

### Capa 4 — Manual Godot + bandeja (evidencia wiki)

Ver sección *Cómo asegurar que lleguen los mails* más abajo.

## Cómo asegurar que lleguen los mails (local)

Los mails **no se disparan solo por abrir Godot**. Necesitás backend + Brevo + cola procesada.

| Mail | Qué lo dispara | Cómo asegurarlo |
|------|----------------|-----------------|
| **Welcome** | Registro con mail | Backend prendido (`npm run dev`). El registro encola `pending` en DB y el servidor procesa la cola al iniciar (`EMAIL_PROCESS_ON_STARTUP=true`) o en background tras registrar. |
| **Racha** | Job diario | Postgres con racha online + `npm run email:streaks` o `npm run email:run-local` (o Task Scheduler 19:00). |
| **Pendientes / fallidos** | Cola outbox | `npm run email:run-local` procesa welcome pending + rachas + reintentos en un solo paso. |

### Flujo recomendado para demo

```bash
docker compose up -d
npm run migrate
npm run dev                    # al iniciar procesa cola outbound si EMAIL_ENABLED=true
# Registrar usuario con mail desde Godot
npm run smoke:email            # validar config
npm run seed:streak-email-demo -- --run-job   # demo racha en riesgo
```

### Outbox welcome

El registro ya no depende de un envío fire-and-forget: primero persiste `email_deliveries.status=pending` y después `processPendingWelcomeEmails()` envía a Brevo. Si el servidor se cayó, al reiniciar (`EMAIL_PROCESS_ON_STARTUP`) o con `email:run-local` se reanuda.

### Coherencia de racha

- El mail `streak_lost` **solo notifica**.
- El reset de `current_count` en Postgres lo hace `reconcileExpiredStreaksInDatabase()` al final del job (inactividad real, independiente del envío).
- Al loguear, Godot sincroniza racha del servidor (`aplicar_racha_sincronizada`).

### Webhook Brevo (rebotes)

`POST /internal/jobs/brevo-webhook` con header `X-Brevo-Webhook-Secret`. En hard bounce desactiva `email_notifications_enabled` para ese mail. Requiere URL pública en producción; en local es opcional.

## Endpoints dev (solo `NODE_ENV !== production`)

```http
GET /dev/email/templates
GET /dev/email/preview?template_key=welcome&name=Agus&mail=agus@test.com
GET /dev/email/preview?template_key=streak_at_risk&name=Agus&streak_count=7
GET /dev/email/deliveries?status=sent&limit=20
```

## Cron local (desarrollo / demo sin deploy)

Si todo corre en tu PC (Postgres Docker + `BACKEND/.env` + Brevo), **no uses GitHub Actions**: no puede llegar a `localhost`.

### Manual

```powershell
# Desde la raíz del repo (PowerShell 5+)
powershell -ExecutionPolicy Bypass -File scripts/local/run-email-job.ps1 -Job streaks
powershell -ExecutionPolicy Bypass -File scripts/local/run-email-job.ps1 -Job retry-failed
```

Equivalente en Git Bash / WSL:

```bash
sh scripts/local/run-email-job.sh streaks
sh scripts/local/run-email-job.sh retry-failed
```

El script levanta `docker compose up -d postgres` y corre `npm run email:*` en `BACKEND/`.

### Automático en Windows (Task Scheduler)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/local/register-email-tasks-windows.ps1
```

| Tarea | Hora (ART) | Job |
|-------|------------|-----|
| `E-VIDENTE-Email-Streaks` | 19:00 | rachas |
| `E-VIDENTE-Email-Retry-AM` | 08:00 | reintento fallidos |
| `E-VIDENTE-Email-Retry-PM` | 20:00 | reintento fallidos |

Quitar tareas:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/local/register-email-tasks-windows.ps1 -Unregister
```

**Requisitos:** Docker Desktop corriendo (o al menos disponible al disparar la tarea), Node/npm en PATH, `.env` con `EMAIL_ENABLED=true` y Brevo configurado.

### Manual directo (sin script)

```bash
cd BACKEND
docker compose up -d
npm run email:streaks
npm run email:retry-failed
```

## Cron de rachas (API / servidor levantado)

Si el backend está corriendo (`npm run dev`), también podés disparar por HTTP:

```bash
npm run email:streaks
# o
POST /internal/jobs/streak-emails
Header: X-Job-Secret: <EMAIL_CRON_SECRET>
```

## Reintento de envíos fallidos

Reprocesa filas `failed` recientes (`attempt_count` < `EMAIL_RETRY_MAX_ATTEMPTS`, default 3) sin duplicar por `dedupe_key`.

```bash
npm run email:retry-failed
# o
POST /internal/jobs/retry-failed-emails
Header: X-Job-Secret: <EMAIL_CRON_SECRET>
```

Variables:

| Variable | Default | Uso |
|----------|---------|-----|
| `EMAIL_RETRY_MAX_ATTEMPTS` | 3 | Máximo de intentos por delivery |
| `EMAIL_RETRY_MAX_AGE_HOURS` | 48 | Solo reintenta fallos de las últimas N horas |
| `EMAIL_RETRY_BATCH_LIMIT` | 50 | Máximo de filas por corrida |

Migración `023_email_deliveries_retry_indexes.sql` agrega índices para dedupe activo y búsqueda de `failed`.

## Cron en GitHub Actions (solo con backend público)

> **Entorno 100 % local:** usá la sección **Cron local** de arriba. El workflow de GitHub no puede llamar a `localhost`.

Cuando tengas el backend desplegado en internet, workflow: `.github/workflows/email-cron.yml`

| Horario (ART, UTC-3) | Job |
|----------------------|-----|
| 19:00 diario | `streak-emails` |
| 08:00 y 20:00 diario | `retry-failed-emails` |

También podés dispararlo a mano: **Actions → Email cron jobs → Run workflow**.

### Secrets del repositorio (Settings → Secrets → Actions)

| Secret | Ejemplo | Debe coincidir con |
|--------|---------|-------------------|
| `BACKEND_BASE_URL` | `https://api.tudominio.com` | URL pública del backend (sin `/` final) |
| `EMAIL_CRON_SECRET` | valor largo | `EMAIL_CRON_SECRET` del servidor |

El workflow hace `POST` a `/internal/jobs/<job>` con header `X-Job-Secret`.

Prueba local del mismo script:

```bash
BACKEND_BASE_URL=http://localhost:3000 \
EMAIL_CRON_SECRET=evidente_email_cron_local_dev_change_me \
sh scripts/ci/trigger-email-job.sh streak-emails
```

## Diseño visual

Los mails replican la UI del juego:

| Token | Valor | Uso en el juego |
|-------|-------|-----------------|
| Verde primario | `#42785e` | Botones, títulos, HUD |
| Chip salvia | `#c7d6a8` | Acentos suaves |
| Fondo crema | `#f4f7f2` | Fondo de escenas |
| Texto cuerpo | `#3e382a` | Labels y párrafos |
| Acento marrón | `#704533` | Mensajes de estado |
| Radio card | `28px` | Paneles de login/perfil |

Tipografía: **Rubik** (Google Fonts). En el juego el display usa Rubik Spray Paint; en email usamos Rubik 900 para el titular por compatibilidad con clientes de correo.

Editar estilos globales en `templates/layout.ts` (`GAME_EMAIL_THEME` + `wrapHtml`).

1. Abrí el archivo en `templates/*.template.ts`
2. Modificá `subject`, `textContent` y el HTML del body
3. Verificá con `GET /dev/email/preview?...`
4. Corré `npm run test:email` (unitarios de templates)

## Tests

```bash
npm run test:email
```
