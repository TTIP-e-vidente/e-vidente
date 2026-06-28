# Migración a Supabase (Postgres)

E-VIDENTE **no migra a Supabase Auth**. Solo movemos **PostgreSQL** a Supabase; el juego sigue hablando con **Express + JWT propio**.

```text
Godot  →  Express (BACKEND)  →  Postgres Supabase
                ↑
         JWT propio (users.password_hash)
```

Supabase Auth, Realtime y Storage **no** forman parte de este flujo hoy.

---

## Qué ya está preparado en el repo

| Pieza | Ubicación |
|-------|-----------|
| SSL remoto | `POSTGRES_SSL=true` → `postgresPoolConfig.ts` |
| Sin Docker si remoto | `ensure-postgres.ts`, `setup-dev.ts` |
| Migraciones SQL | `BACKEND/migrations/` (001–030) |
| RLS en `public` | `030_supabase_public_rls_lockdown.sql` |
| Setup staging | `npm run setup:supabase` |
| Copia de datos local | `npm run migrate:data-to-supabase` |
| Smoke contra staging | `npm run smoke:api:staging` |

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
```

### 3. Schema (migraciones)

Usá **conexión directa** (no pooler) para DDL:

```powershell
npm run setup:supabase
```

Esto valida conexión, corre `001…030` y registra `schema_migrations`.

### 4. (Opcional) Datos desde Docker local

Si tenés usuarios/progreso en Docker local y querés llevarlos a Supabase:

```powershell
npm run setup:dev          # local con datos demo, si hace falta
npm run migrate:data-to-supabase:dry-run
npm run migrate:data-to-supabase
```

**Atención:** `--apply` hace `TRUNCATE … CASCADE` en Supabase antes de copiar.

### 5. Runtime con pooler

Tras migrar, en `.env.staging` podés cambiar a **Session pooler** (mejor para muchas conexiones):

```env
POSTGRES_HOST=aws-0-us-east-1.pooler.supabase.com
POSTGRES_USER=postgres.TU_REF
```

### 6. Validar

```powershell
npm run smoke:api:staging
npm run dev:staging
```

Godot apunta al mismo `BACKEND_PORT` (3010); solo cambia la DB detrás.

---

## Entornos

| Entorno | Env file | Comando setup | Postgres |
|---------|----------|---------------|----------|
| Dev local | `.env` | `npm run setup:dev` | Docker |
| Staging Supabase | `.env.staging` | `npm run setup:supabase` | Supabase |
| CI tests | `.env` + `EMAIL_ENABLED=false` | `npm test` | Docker |

---

## Producción (cuando toque)

1. Proyecto Supabase **prod** separado de staging.
2. `.env` en el servidor (no commitear) con pooler + secrets de prod.
3. `ENV_FILE=.env npm run migrate` en deploy (o `setup:supabase` equivalente).
4. Brevo + dominio verificado (SPF/DKIM).
5. Backups: Supabase dashboard → Database → Backups (plan Pro) o `pg_dump` programado.

---

## Troubleshooting

| Error | Causa | Solución |
|-------|-------|----------|
| `POSTGRES_SSL=true es obligatorio` | Falta flag en `.env.staging` | `POSTGRES_SSL=true` |
| SSL / timeout en migrate | Usás pooler para DDL | Host `db.<ref>.supabase.co` |
| `password authentication failed` | Password incorrecta | Reset en Supabase dashboard |
| `setup:dev` con SSL true | Comando equivocado | Usá `setup:supabase` |
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
npm run setup:supabase
npm run migrate:data-to-supabase:dry-run
npm run migrate:data-to-supabase
npm run smoke:api:staging
npm run dev:staging
```
