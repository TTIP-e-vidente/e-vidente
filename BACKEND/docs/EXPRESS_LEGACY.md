# Express API — legacy (referencia y tests locales)

**Estado:** deprecado para juego online. La API de producción/staging es **Supabase Edge Functions**.

Stack actual: [SUPABASE_QUICKSTART.md](./SUPABASE_QUICKSTART.md)

## Cuándo sigue existiendo Express

| Uso | ¿Necesario para jugar online? |
|-----|-------------------------------|
| Godot con `api_mode: supabase_edge` | **No** |
| Tests unitarios Node (`npm test`) | Sí (mocks / rutas legacy) |
| `smoke:api` contra Express local | Solo si portás lógica nueva antes de Edge |
| Render / `BACKEND_BASE_URL` | **No** (reemplazado por Edge + pg_cron) |

## Stack actual (objetivo)

```text
Godot → Supabase Edge Functions → Postgres + Storage + Brevo
pg_cron → internal-job (Edge)
```

## Comandos legacy (no usar para demo online)

```powershell
cd BACKEND
npm run dev          # Levanta Express :3010 — solo desarrollo de módulos Node
npm run smoke:api    # Smoke contra Express, no Edge
```

## Equivalentes Edge (usar estos)

```powershell
npm run integrate:staging           # migrate + deploy + cron + godot + smokes
npm run verify:integration:full     # verificación integral (recomendado)
npm run smoke:edge:staging          # auth + progress + avatar + leaderboard
npm run integrate:status              # panel integración
```

## Rutas Express duplicadas (pendiente de eliminar en código)

- `POST /player/verify-email/*` → ya en `verify-email-*` (Edge)
- `POST /internal/jobs/*` → ya en `internal-job` (Edge)

No borrar el código Express hasta cerrar tests Node que dependan de él.
