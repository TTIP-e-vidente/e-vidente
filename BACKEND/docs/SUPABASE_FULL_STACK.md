# Migrar el backend a Supabase — stack completo

> **Importante:** Supabase hospeda **Postgres**, no Express.  
> “Migrar el backend” en E-VIDENTE = **DB en Supabase** + **API Node desplegada en la nube** apuntando a esa DB.

```text
┌─────────┐     HTTPS      ┌──────────────────┐     SSL      ┌─────────────────┐
│  Godot  │ ─────────────► │ Express (Node)   │ ───────────► │ Supabase        │
│         │                │ Render/Railway/  │   pooler     │ Postgres        │
│         │                │ Docker           │              │                 │
└─────────┘                └────────┬─────────┘              └─────────────────┘
                                    │
                           GitHub Actions (crons email)
                                    POST /internal/jobs/*
```

**No usamos:** Supabase Auth, REST API, Edge Functions (la lógica sigue en Express + JWT propio).

---

## Fases de migración

| Fase | Qué | Estado en tu proyecto |
|------|-----|------------------------|
| 1 | Postgres + schema + RLS | Hecho (30 migraciones, verify OK) |
| 2 | Backend local → Supabase | `npm run dev:staging` |
| 3 | Deploy Express en cloud | Pendiente (Render/Docker) |
| 4 | Crons + Brevo prod | Pendiente (secrets GitHub) |

---

## Fase 1 — Base de datos (hecho)

```powershell
cd BACKEND
npm run supabase:status      # resumen
npm run verify:supabase      # chequeo profundo
```

Tu proyecto: `kpvjdzdynqfhqfiatwqz` · pooler `aws-1-us-east-1`.

---

## Fase 2 — Desarrollo contra Supabase

```powershell
npm run dev:staging
```

- Conecta automáticamente (fallback pooler si hace falta)
- Sincroniza URL Godot → `backend.local.json`
- Al arrancar valida Supabase + migraciones

Login demo: `agus` / `123`

---

## Fase 3 — Deploy del backend (Express)

Elegí **una** opción:

### A) Render (recomendado, más simple)

1. Conectá el repo en [render.com](https://render.com)
2. Usá `BACKEND/render.yaml` (Blueprint)
3. Variables desde `.env.production.example`:
   - `POSTGRES_HOST=aws-1-us-east-1.pooler.supabase.com`
   - `POSTGRES_USER=postgres.kpvjdzdynqfhqfiatwqz`
   - `POSTGRES_PASSWORD="..."` (con comillas si tiene `#`)
   - `POSTGRES_SSL=true`
   - `JWT_SECRET`, `EMAIL_CRON_SECRET`, `BREVO_*`
   - `BACKEND_BASE_URL=https://tu-servicio.onrender.com`
4. Health check: `/health/ready`
5. Start: `npm run start:prod` (migrate + server)

### B) Docker

```powershell
cd BACKEND
docker build -t e-vidente-api .
docker run --env-file .env.production -p 3000:3000 e-vidente-api
```

### C) Railway / Fly.io

Mismo patrón: build → `npm run start:prod` → env de producción.

---

## Fase 4 — Crons y emails

1. Backend con URL pública (`BACKEND_BASE_URL`)
2. GitHub Secrets:
   - `BACKEND_BASE_URL`
   - `EMAIL_CRON_SECRET` (igual que en el servidor)
3. Probar: `npm run smoke:cron:staging` (con URL pública en env)
4. Workflow: `.github/workflows/email-cron.yml` (ya existe)

---

## Comandos del flujo

| Comando | Cuándo |
|---------|--------|
| `supabase:init` | Primera vez |
| `supabase:diagnose` | Problemas de conexión |
| `supabase:bootstrap:apply:seed` | Schema + usuarios demo |
| `supabase:status` | Ver estado rápido |
| `dev:staging` | Desarrollo diario |
| `check:deploy:staging` | Preflight |
| `start:prod` | Deploy (migrate + API) |

---

## Qué NO conviene migrar a Supabase

| Opción | Por qué no (hoy) |
|--------|------------------|
| Supabase Auth | Duplicaría login JWT existente + cambios en Godot |
| Edge Functions | Reescribir toda la API |
| REST/Data API | RLS bloqueado (030); backend usa rol postgres |

---

## Próximo paso concreto

1. Crear servicio en **Render** con `render.yaml`
2. Copiar `.env.staging` → secrets de prod (password rotada)
3. `BACKEND_BASE_URL` = URL de Render
4. Configurar secrets GitHub para crons

Guía rápida: [SUPABASE_QUICKSTART.md](./SUPABASE_QUICKSTART.md)
