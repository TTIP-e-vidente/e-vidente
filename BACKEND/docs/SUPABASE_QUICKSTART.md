# Guía rápida Supabase (5 minutos)

**Stack actual (staging):** Godot → **Supabase Edge Functions** → Postgres + Storage. Mails → Edge + Brevo + `pg_cron`.

```text
Godot (api_mode=supabase_edge)
  → Edge Functions (auth, progreso, avatar, ranking, verify-mail)
  → Postgres Supabase
  → Storage (avatares)
pg_cron → internal-job → Brevo
```

**Express** queda solo para tests Node legacy — [EXPRESS_LEGACY.md](./EXPRESS_LEGACY.md).  
**No hace falta** `npm run dev` para jugar online.

Detalle Edge: [SUPABASE_EDGE_FUNCTIONS.md](./SUPABASE_EDGE_FUNCTIONS.md)

---

## 1. Crear proyecto Supabase

1. [dashboard.supabase.com](https://dashboard.supabase.com) → **New project**
2. Anotá **project ref** y **database password**
3. En **Settings → Database**:
   - **Direct** (migrate): `db.<ref>.supabase.co` · user `postgres`
   - **Pooler** (runtime): `aws-0-….pooler.supabase.com` · user `postgres.<ref>`

---

## 2. Setup staging (recomendado)

```powershell
cd BACKEND
npm install

# Keys anon/publishable (no commitear)
copy docs\env.supabase-keys.local.example .env.supabase-keys.local
# Pegar SUPABASE_ANON_KEY del dashboard → Settings → API

npm run configure:supabase-keys
npm run integrate:staging
```

`integrate:staging` hace: migraciones → deploy Edge → pg_cron → sync Godot → smokes.

Si la DB no conecta:

```powershell
npm run supabase:diagnose    # prueba poolers y persiste host en .env.staging
```

**Password con `#`:** en el `.env` va entre comillas → `POSTGRES_PASSWORD="tu#pass"`.

---

## 3. Jugar (sin Express)

```powershell
# Verificación rápida
npm run integrate:status

# Verificación completa (~3 min) — sin dudas
npm run verify:integration:full
```

Godot 4.6 → `juego/project.godot` → **F5** → login → jugar.

`juego/config/backend.local.json` debe tener `api_mode: supabase_edge` (lo escribe `sync:godot-config:staging`).

**Ranking post-partida:** al guardar progreso, Edge refresca en background los scopes relevantes (`global_xp`, `streak` si completó, y la restricción jugada). El cron horario sigue como respaldo.

---

## 4. Brevo (mails OTP + rachas)

Secrets en Edge (no en Express):

```powershell
# BREVO_API_KEY, BREVO_SENDER_EMAIL, EMAIL_ENABLED=true en .env.staging
npm run sync:staging-secrets
npm run supabase:functions:secrets
npm run smoke:brevo-edge
```

OTP end-to-end:

```powershell
npm run smoke:verify-email-edge
# Casilla real:
# $env:SMOKE_EMAIL_TO="tu@mail.com"
# npm run smoke:verify-email-edge -- --send
```

Detalle: [BREVO_SETUP.md](./BREVO_SETUP.md) · [SUPABASE_EDGE_FUNCTIONS.md](./SUPABASE_EDGE_FUNCTIONS.md)

---

## 5. Crons (pg_cron en Supabase)

Los jobs corren **en Supabase**, no en GitHub ni Express:

```powershell
npm run setup:supabase:cron
npm run smoke:cron:staging -- streak-at-risk-emails
```

| Job pg_cron | Horario ART | Edge `internal-job` |
|-------------|-------------|---------------------|
| `evidente-streak-at-risk` | 18:00 | `streak-at-risk-emails` |
| `evidente-streak-lost` | 00:00 | `streak-lost-emails` |
| `evidente-retry-failed-am/pm` | 08:00 / 20:00 | `retry-failed-emails` |
| `evidente-refresh-leaderboard` | cada hora :15 UTC | `refresh-leaderboard` |

Los jobs corren **solo en Supabase** (`pg_cron` → Edge). No hay workflow de crons en GitHub.

---

## 6. Producción (pendiente)

1. Proyecto Supabase **prod** separado de staging
2. `npm run prod:init-env` → `.env.production`
3. `ENV_FILE=.env.production npm run integrate:staging` (o pasos equivalentes)
4. `ENV_FILE=.env.production npm run verify:integration:full`

---

## Comandos útiles

| Comando | Para qué |
|---------|----------|
| `npm run integrate:staging` | Setup completo staging |
| `npm run integrate:status` | Panel DB + Edge + cron + Godot |
| `npm run verify:integration:full` | **Verificación integral** (recomendado) |
| `npm run smoke:edge:staging` | Smokes auth/progress/avatar/leaderboard |
| `npm run check:edge:staging` | Guards Edge (JWT, internal-job) |
| `npm run verify:supabase` | Schema + RLS + migraciones (35/35) |
| `npm run supabase:functions:deploy` | Redeploy Edge Functions |
| `npm run sync:godot-config:staging` | Solo `backend.local.json` |
| `npm run dev` | **Legacy:** Express :3010 (solo tests Node) |

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| Timeout en migrate | Host **directo**, no pooler |
| `integrate:status` falla Edge | `npm run supabase:functions:deploy` |
| Brevo no configurado | `sync:staging-secrets` + `supabase:functions:secrets` |
| Crons omitidos | `npm run setup:supabase:cron` |
| Godot pide localhost | `npm run sync:godot-config:staging` |
