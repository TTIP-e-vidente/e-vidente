# Guía rápida Supabase (5 minutos)

Integración **solo Postgres**. Auth sigue siendo Express + JWT.

```text
Godot → Express → Supabase Postgres
              ↑
        GitHub Actions (crons email)
```

---

## 1. Crear proyecto Supabase

1. [dashboard.supabase.com](https://supabase.com/dashboard) → **New project**
2. Anotá **project ref** y **database password**
3. En **Settings → Database**:
   - **Direct** (migrate): `db.<ref>.supabase.co` · user `postgres`
   - **Pooler** (runtime): `aws-0-….pooler.supabase.com` · user `postgres.<ref>`

---

## 2. Un solo comando (recomendado)

```powershell
cd BACKEND
npm install

npm run supabase:init
# Editar .env.staging: password, JWT_SECRET, EMAIL_CRON_SECRET
# Agregar: SUPABASE_PROJECT_REF=<ref>  (habilita fallback automático al pooler)

npm run supabase:diagnose          # prueba DNS + conexión; persiste pooler si hace falta
npm run supabase:bootstrap:apply:seed
```

Si `db.<ref>.supabase.co` falla (IPv6/DNS), `supabase:diagnose` prueba poolers (`aws-1`/`aws-0`) y **persiste el host que funciona** en `.env.staging`.

**Password con `#`:** en el `.env` va entre comillas → `POSTGRES_PASSWORD="tu#pass"`.

Con datos locales:

```powershell
npm run supabase:bootstrap:full
```

---

## 3. Desarrollo contra Supabase

```powershell
npm run staging:verify   # recomendado antes de demo
npm run dev:staging
```

Godot usa `juego/config/backend.local.json` (generado automáticamente).

Emails contra staging: `npm run validate:email-flow:staging` (requiere Brevo en `.env.staging`).

---

## 4. Deploy del backend (Render u otro)

1. Conectá el repo y usá `BACKEND/render.yaml` o configurá manualmente:
   - **Build:** `npm ci && npm run build`
   - **Start:** `npm run start:prod` (migrate + server)
   - **Health:** `GET /health/ready`

2. Variables en el host (ver `.env.production.example`):

| Variable | Valor |
|----------|-------|
| `POSTGRES_HOST` | Session pooler |
| `POSTGRES_USER` | `postgres.<ref>` |
| `POSTGRES_PASSWORD` | password Supabase |
| `POSTGRES_SSL` | `true` |
| `POSTGRES_POOL_MAX` | `8` |
| `JWT_SECRET` | secret largo |
| `EMAIL_CRON_SECRET` | secret largo |
| `BACKEND_BASE_URL` | `https://tu-api...` |
| `BREVO_API_KEY` | API key |
| `BREVO_SENDER_EMAIL` | remitente verificado |

3. Preflight antes del deploy:

```powershell
ENV_FILE=.env.production npm run check:deploy -- --production
```

---

## 5. Crons de email (GitHub Actions)

Los crons **no corren en Supabase**. Corren cuando el backend está **público en internet**.

1. Deploy del backend con URL pública
2. En GitHub → **Settings → Secrets → Actions**:

| Secret | Valor |
|--------|-------|
| `BACKEND_BASE_URL` | `https://tu-api...` |
| `EMAIL_CRON_SECRET` | mismo que en el servidor |

3. Probar:

```powershell
npm run smoke:cron:staging
# o manual: Actions → Email cron jobs → Run workflow
```

Horarios (ART): rachas 19:00 · retry 08:00 y 20:00.

---

## Comandos útiles

| Comando | Para qué |
|---------|----------|
| `npm run supabase:init` | Crear `.env.staging` |
| `npm run staging:verify` | Chequeo completo (status + deploy + schema + smoke) |
| `npm run supabase:bootstrap -- --apply` | Schema + verify |
| `npm run check:deploy:staging` | Preflight staging |
| `npm run verify:supabase` | Chequeo DB/RLS/migraciones |
| `npm run validate:email-flow:staging` | E2E mails con Brevo |
| `npm run seed:staging` | Usuarios demo |
| `npm run start:prod` | Migrate + server (deploy) |
| `GET /health/ready` | Probe para Render/Railway |

---

## Troubleshooting

| Problema | Solución |
|----------|----------|
| Timeout en migrate | Usá host **directo**, no pooler |
| Crons no corren | Falta deploy público o secrets GitHub |
| `not_ready` en /health/ready | Corré `npm run deploy:migrate` |
| Pool agotado | Bajá `POSTGRES_POOL_MAX` a 5–8 |

Guía completa: [SUPABASE_MIGRATION.md](./SUPABASE_MIGRATION.md)
