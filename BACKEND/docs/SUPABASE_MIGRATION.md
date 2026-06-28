> **Stack completo (DB + deploy Express):** [SUPABASE_FULL_STACK.md](./SUPABASE_FULL_STACK.md)

E-VIDENTE **no migra a Supabase Auth**. Solo movemos **PostgreSQL** a Supabase; el juego sigue hablando con **Express + JWT propio**.

```text
Godot  →  Express (BACKEND)  →  Postgres Supabase
                ↑
         JWT propio (users.password_hash)
```

Supabase Auth, Realtime y Storage **no** forman parte de este flujo hoy.

---

## Qué está integrado en el repo

| Pieza | Comando / ubicación |
|-------|---------------------|
| SSL remoto | `POSTGRES_SSL=true` → `postgresPoolConfig.ts` |
| Sin Docker si remoto | `ensure-postgres.ts`, `setup-dev.ts` |
| Migraciones SQL | `BACKEND/migrations/` (001–030) |
| RLS en `public` | `030_supabase_public_rls_lockdown.sql` |
| Setup schema | `npm run setup:supabase` |
| Copia de datos (orden FK) | `npm run migrate:data-to-supabase` |
| Verificación post-migrate | `npm run verify:supabase` |
| Orquestador completo | `npm run migrate:all-to-supabase` |
| Migrate en deploy | `npm run deploy:migrate` |
| Smoke staging | `npm run smoke:staging` |
| CI manual | `.github/workflows/supabase-staging-verify.yml` |

La migración **030** activa RLS en todas las tablas `public`. El backend Node usa el rol `postgres` y **no se ve afectado**; bloquea acceso directo vía Data API de Supabase sin policies.

---

## Flujo recomendado (staging)

### 1. Crear proyecto Supabase

1. [dashboard.supabase.com](https://supabase.com/dashboard) → New project.
2. Anotá **Project ref** (subdominio) y **Database password**.
3. **Project Settings → Database**:
   - **Direct connection**: `db.<ref>.supabase.co:5432` → user `postgres`
   - **Session pooler** (runtime): `aws-0-….pooler.supabase.com` → user `postgres.<ref>`

### 2. Configurar entorno staging

```powershell
cd BACKEND
copy .env.staging.example .env.staging
# Editar .env.staging con host DIRECT, password, JWT_SECRET, Brevo si aplica
```

Variables críticas:

```env
POSTGRES_HOST=db.TU_REF.supabase.co
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=...
POSTGRES_SSL=true
JWT_SECRET=<secret fuerte, no el placeholder>
```

### 3. Migración completa (recomendado)

**Preview (sin escribir en Supabase):**

```powershell
npm run migrate:all-to-supabase -- --dry-run
```

**Aplicar schema + datos + verificación + smoke:**

```powershell
npm run migrate:all-to-supabase -- --apply --with-smoke
```

Flags útiles:

| Flag | Efecto |
|------|--------|
| `--dry-run` | Solo preview de datos (default sin `--apply`) |
| `--apply` | Ejecuta setup, copia datos y verify |
| `--with-smoke` | Corre `smoke:api:staging` al final |
| `--skip-setup` | Omite `setup:supabase` (schema ya aplicado) |
| `--skip-data` | Solo schema/verify, sin copiar datos |

### 4. Pasos manuales (alternativa)

**Solo schema:**

```powershell
npm run setup:supabase
```

Incluye `verify:supabase` al final.

**Datos desde Docker local** (orden topológico por FK, batch insert):

```powershell
npm run setup:dev
npm run migrate:data-to-supabase:dry-run
npm run migrate:data-to-supabase
npm run verify:supabase:compare-local
```

**Sin datos locales** (usuarios demo en Supabase):

```powershell
npm run seed:staging
```

**Atención:** `--apply` hace `TRUNCATE … CASCADE` en Supabase antes de copiar.

### 5. Runtime con pooler

Tras migrar, en `.env.staging` podés cambiar a **Session pooler**:

```env
POSTGRES_HOST=aws-0-us-east-1.pooler.supabase.com
POSTGRES_USER=postgres.TU_REF
```

### 6. Validar

```powershell
npm run verify:supabase
npm run smoke:staging
npm run dev:staging
```

Godot apunta al mismo `BACKEND_PORT` (3010); solo cambia la DB detrás.

---

## Producción

1. Proyecto Supabase **prod** separado de staging.
2. Copiar `.env.production.example` → `.env.production` en el servidor.
3. En cada deploy:

```powershell
ENV_FILE=.env.production npm run deploy:migrate
```

O en Linux:

```bash
npx ts-node scripts/deploy-migrate.ts .env.production
```

4. Configurar en el host de deploy:
   - `BACKEND_BASE_URL` y `EMAIL_CRON_SECRET` (GitHub Secrets para `email-cron.yml`)
5. Brevo + dominio verificado (SPF/DKIM).
6. Backups: Supabase dashboard → Database → Backups (plan Pro) o `pg_dump` programado.

---

## CI (GitHub Actions)

Workflow manual: **Supabase staging verify** (`supabase-staging-verify.yml`).

Secrets requeridos en el repo:

| Secret | Descripción |
|--------|-------------|
| `STAGING_POSTGRES_HOST` | Host directo o pooler |
| `STAGING_POSTGRES_PASSWORD` | Password de DB |
| `STAGING_JWT_SECRET` | JWT del backend staging |
| `STAGING_POSTGRES_USER` | (opcional) default `postgres` |
| `STAGING_POSTGRES_PORT` | (opcional) default `5432` |
| `STAGING_POSTGRES_DB` | (opcional) default `postgres` |

El workflow escribe `.env.staging` vía `scripts/ci/write-staging-env.sh` y corre `verify:supabase` + smoke opcional.

---

## Entornos

| Entorno | Env file | Comando setup | Postgres |
|---------|----------|---------------|----------|
| Dev local | `.env` | `npm run setup:dev` | Docker |
| Staging Supabase | `.env.staging` | `npm run setup:supabase` | Supabase |
| Producción | `.env.production` | `npm run deploy:migrate` | Supabase |
| CI tests | `.env` + `EMAIL_ENABLED=false` | `npm test` | Docker |

---

## Troubleshooting

| Error | Causa | Solución |
|-------|-------|----------|
| `POSTGRES_SSL=true es obligatorio` | Falta flag en `.env.staging` | `POSTGRES_SSL=true` |
| SSL / timeout en migrate | Usás pooler para DDL | Host `db.<ref>.supabase.co` |
| `password authentication failed` | Password incorrecta | Reset en Supabase dashboard |
| `setup:dev` con SSL true | Comando equivocado | Usá `setup:supabase` |
| FK violation al copiar datos | Orden incorrecto (viejo) | Actualizá repo; usa `migrate:data-to-supabase` actual |
| `JWT_SECRET sigue siendo placeholder` | verify:supabase | Cambiá el secret en `.env.staging` |
| Tests tocan Brevo | Normal en CI | `npm test` fuerza `EMAIL_ENABLED=false` |

---

## Qué NO migramos en esta fase

- Supabase Auth (login seguiría siendo Express).
- Edge Functions (lógica sigue en Node).
- Storage de avatares (sigue en `images` + API propia).
- Supabase CLI / `supabase link` (opcional futuro; hoy usamos migraciones SQL propias).

---

## Comandos rápidos

```powershell
cd BACKEND
npm run migrate:all-to-supabase -- --apply --with-smoke
npm run verify:supabase
npm run seed:staging
npm run dev:staging
```
