# Mails y jobs en Supabase Edge Functions

**API de juego (auth, progreso, perfil, avatares, leaderboard):** Supabase Edge — ver [SUPABASE_QUICKSTART.md](./SUPABASE_QUICKSTART.md).

**Express:** solo legacy para tests locales — [EXPRESS_LEGACY.md](./EXPRESS_LEGACY.md).

## Arquitectura

```text
Godot ──login/progreso/perfil/ranking──► Edge Functions (api_mode=supabase_edge)
Godot ──verify OTP──────────────────────► Edge: verify-email-request / confirm
pg_cron (Supabase) ─────────────────────► Edge: internal-job
                                              ├─ streak-at-risk-emails  (18:00 ART)
                                              ├─ streak-lost-emails     (00:00 ART)
                                              ├─ retry-failed-emails
                                              └─ refresh-leaderboard
Edge Functions ──► Postgres + Storage (avatares) + Brevo
```

## Setup (una vez)

1. **`BACKEND/.env.staging` + `.env.supabase-keys.local`:**
   ```env
   SUPABASE_PROJECT_REF=<ref>
   SUPABASE_PUBLISHABLE_KEY=<sb_publishable_...>   # preferido
   SUPABASE_ANON_KEY=<legacy anon JWT>             # opcional
   JWT_SECRET=...
   EMAIL_CRON_SECRET=...
   BREVO_API_KEY=...
   BREVO_SENDER_EMAIL=...
   ```

2. **Integración completa:**
   ```powershell
   cd BACKEND
   npm run integrate:staging
   ```
   (migraciones, deploy Edge, pg_cron, sync Godot, smokes)

3. **Verificar:**
   ```powershell
   npm run integrate:status
   npm run verify:integration:full   # integral (~3 min) — recomendado
   npm run smoke:edge:staging
   npm run smoke:brevo-edge
   npm run smoke:verify-email-edge
   npm run check:edge:staging
   ```

## Flujo verify en Godot

1. `email_via_supabase: true` en `backend.local.json`
2. OTP → `verify-email-request` / `verify-email-confirm`
3. Mails automáticos → `pg_cron` → `internal-job`

## Secrets Edge

| Secret | Uso |
|--------|-----|
| `DATABASE_URL` | Postgres |
| `JWT_SECRET` | Login + sesión |
| `EMAIL_CRON_SECRET` | `internal-job` |
| `GAME_CLIENT_API_KEYS` | publishable + anon (deploy) |
| `BREVO_*` | Mails |
| `BREVO_WEBHOOK_SECRET` | Webhook bounce/unsubscribe → Edge `brevo-webhook` |

`npm run supabase:functions:secrets`

## Crons (solo Supabase pg_cron)

Los jobs programados corren **dentro de Supabase** con `pg_cron` + `pg_net` → `internal-job` (Edge). **No** usamos GitHub Actions para mails ni rachas.

```powershell
npm run setup:supabase:cron
```

| Job pg_cron | Horario ART | Edge `internal-job` |
|-------------|-------------|---------------------|
| `evidente-streak-at-risk` | 18:00 | `streak-at-risk-emails` |
| `evidente-streak-lost` | 00:00 | `streak-lost-emails` |
| `evidente-retry-failed-am` | 08:00 | `retry-failed-emails` |
| `evidente-retry-failed-pm` | 20:00 | `retry-failed-emails` |
| `evidente-refresh-leaderboard` | cada hora :15 UTC | `refresh-leaderboard` |

**Probar manualmente** (mismo camino que pg_cron):

```powershell
npm run smoke:cron:staging -- streak-at-risk-emails
npm run verify:integration:full   # dispara todos los jobs
```

**Observabilidad:** tabla `private.cron_invocation_log` · fila en `npm run integrate:status` (“Crons recientes”).

### CI en GitHub (solo verificación, no crons)

| Workflow | Para qué |
|----------|----------|
| `supabase-staging-verify.yml` | `verify:supabase` + smokes Edge (manual dispatch) |

No hace falta configurar secrets de GitHub para que salgan los mails: todo lo hace pg_cron en el proyecto Supabase.

Verificación local:

```powershell
npm run verify:integration:full
npm run integrate:status
```

## Brevo (Edge)

1. **Secrets:** `BREVO_API_KEY`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME` → `npm run supabase:functions:secrets`
2. **Probe en runtime:** `GET /verify-email-health` llama a Brevo `/v3/account` y devuelve `brevo_probe` + `delivery_configured`
3. **Webhook (recomendado):** en Brevo → Email transaccional → Webhook:
   - URL: `https://<ref>.supabase.co/functions/v1/brevo-webhook`
   - Header: `X-Brevo-Webhook-Secret: <BREVO_WEBHOOK_SECRET>` (mismo valor en `.env.staging` y Edge secrets)
   - Eventos: hard bounce, soft bounce, blocked, unsubscribed
4. **Smoke:** `npm run smoke:brevo-edge`

Ver `docs/BREVO_SETUP.md` (remitente verified, Authorized IPs desactivadas para Edge).

## Producción

Mismo stack con `.env.production`:

```powershell
$env:ENV_FILE=".env.production"
npm run migrate
npm run supabase:functions:deploy
npm run setup:supabase:cron
npm run sync:godot-config
npm run verify:integration:full
```

Ver `docs/env.production.example`.
