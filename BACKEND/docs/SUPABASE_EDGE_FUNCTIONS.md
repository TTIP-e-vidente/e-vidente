# Mails y jobs en Supabase Edge Functions

**Auth y progreso siguen en Express** (login JWT). **Todo lo de mail** (verify OTP, rachas, retry, welcome pendiente) corre en Supabase cuando está desplegado.

OAuth **no** está incluido — en Godot desktop suma complejidad sin simplificar verify.

## Arquitectura

```text
Godot ──login/progreso──► Express (local o Render)
Godot ──verify OTP──────► Edge: verify-email-request / confirm
pg_cron (Supabase) ─────► Edge: internal-job
                              ├─ streak-emails
                              ├─ retry-failed-emails
                              └─ refresh-leaderboard → proxy Express (opcional)
Edge Functions ──► Postgres + Brevo
```

## Setup (una vez)

1. **`BACKEND/.env.staging`:**
   ```env
   SUPABASE_PROJECT_REF=<ref>
   SUPABASE_ANON_KEY=<anon public key>
   JWT_SECRET=...
   EMAIL_CRON_SECRET=...
   BREVO_API_KEY=...
   BREVO_SENDER_EMAIL=...
   ```

2. **Deploy:**
   ```powershell
   npx supabase login
   cd BACKEND
   npm run migrate:supabase          # incluye migración 033 (cron → edge)
   npm run supabase:functions:deploy
   npm run setup:supabase:cron
   npm run sync:godot-config
   ```

3. **Verificar:**
   ```powershell
   npm run smoke:verify-edge
   npm run verify:supabase
   ```

## Flujo verify en Godot

1. Login (Express).
2. Guardar mail en perfil.
3. Botón verificar → Supabase manda OTP por Brevo.
4. Pegar 6 dígitos → Supabase marca `mail_verified_at`.

`BackendConfig.email_via_supabase()` se activa solo si hay `supabase_functions_url` + `supabase_anon_key` en `backend.local.json`.

## Jobs automáticos (pg_cron)

| Job | Horario UTC | Edge Function |
|-----|-------------|---------------|
| streak-emails | 22:00 | `internal-job` |
| retry-failed | 11:00, 23:00 | `internal-job` |
| refresh-leaderboard | :15 cada hora | proxy a Express* |

\* Leaderboard sigue en Express hasta portarlo; mails **no** dependen de Express.

## Supervisión

- **Logs:** Supabase Dashboard → Edge Functions → Logs
- **Crons:** `SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 20;`
- **Mails fallidos:** `SELECT * FROM email_deliveries WHERE status = 'failed' ORDER BY failed_at DESC;`
- **Smoke:** `npm run smoke:verify-edge`

## Secrets Edge Functions

| Secret | Uso |
|--------|-----|
| DATABASE_URL | Postgres |
| JWT_SECRET | Verify OTP (token Express) |
| EMAIL_CRON_SECRET | internal-job (header X-Job-Secret) |
| BREVO_* | Envío transactional |
| SUPABASE_ANON_KEY | Validación gateway |
| BACKEND_BASE_URL | Opcional — solo leaderboard cron |

## ¿Por qué no OAuth?

OAuth (Google) requiere Supabase Auth, deep links en Godot y migrar `users` ↔ `auth.users`. El OTP actual ya funciona con mail/password y **no necesita terminal** una vez desplegado.

---

## Producción — checklist

### 1. Entornos separados

| | Staging | Producción |
|---|---------|------------|
| Supabase project | `kpvjdz…` (actual) | **Proyecto nuevo** recomendado |
| Secrets | `.env.staging` | `.env.production` (ver `docs/env.production.example`) |
| Brevo sender | Gmail dev OK | **Dominio verificado** |
| JWT / cron secrets | dev | **Rotar** — no reutilizar staging |

### 2. Bootstrap automatizado

```powershell
cp BACKEND/docs/env.production.example BACKEND/.env.production
# Completar todos los valores

npx supabase login
cd BACKEND
npm run prod:bootstrap
```

Hace: migraciones 033, deploy Edge Functions, pg_cron → Edge, sync Godot, checks.

### 3. Express en Render (login + progreso)

- Blueprint: `BACKEND/render.yaml`
- Variables desde `.env.production`
- `BACKEND_BASE_URL=https://e-vidente-api.onrender.com`
- Health: `GET /health/ready`
- `EMAIL_PROCESS_ON_STARTUP=false` en prod (mails van por Edge)

### 4. Verificación continua

```powershell
npm run check:deploy:production   # DB + env + Edge
npm run check:edge:production
npm run verify:supabase           # con ENV_FILE=.env.production
```

### 5. Supervisión en prod

- **Supabase → Edge Functions → Logs** — errores Brevo, OTP, crons
- **SQL:** `SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 20;`
- **SQL:** `SELECT status, count(*) FROM email_deliveries GROUP BY status;`
- **Render → Logs** — login, progreso, `/health/ready`

### 6. Godot release

```powershell
$env:ENV_FILE=".env.production"; npm run sync:godot-config
```

Exportar con `email_via_supabase: true` y `base_url` = Render.

### 7. Qué corre dónde en prod

```
Jugadores → Render (Express)     auth, perfil, progreso, leaderboard API
Jugadores → Supabase Edge        verify OTP
pg_cron   → Supabase Edge        rachas, retry mails
pg_cron   → Render (opcional)    refresh-leaderboard si BACKEND_BASE_URL en Edge secrets
```
