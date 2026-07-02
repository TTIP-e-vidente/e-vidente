# Platform Doctor

Chequeo de salud de los subsistemas de la Platform V1.

```bash
npm run platform:doctor            # contra .env (local)
npm run platform:doctor:staging    # contra .env.staging (Supabase)
```

Salida: una línea `OK | WARN | FAIL` por subsistema y resumen final.
Exit code `1` si hay algún FAIL (usable en CI).

| Subsistema | Qué verifica | FAIL cuando |
|---|---|---|
| `env` | `JWT_SECRET`, `POSTGRES_HOST/USER/DB` presentes | falta alguna |
| `email` | Brevo configurado si `EMAIL_ENABLED=true` | enabled sin API key/sender |
| `storage` | `SUPABASE_URL` + `SERVICE_ROLE_KEY` (o solo project ref → WARN) | — |
| `db` | `SELECT now()` contra Postgres | inaccesible |
| `outbox` | resumen `email_deliveries` por status; failed fuera de ventana de retry | — (WARN) |
| `auth` | usuarios con mail y cuántos sin verificar | — |
| `avatars` | filas de `images` por tipo (storage / base64 legacy / vacías) | — (WARN) |
| `sync` | `client_run_id` duplicados en `games` | hay duplicados |
| `cron` | edad de la última fila de `private.cron_invocation_log` | — (WARN si > 90 min) |

Notas:

- En local es normal ver WARN en `email` (tests corren con `EMAIL_ENABLED=false`),
  `storage` y `cron`.
- En staging/prod, un WARN de `cron` > 90 min significa que pg_cron no está
  invocando `internal-job`: revisar `npm run integrate:status` y
  `SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 5;`.
- El test `tests/platform.doctor.test.ts` corre el doctor dentro de `npm test`
  y falla si aparece cualquier FAIL contra la DB local.
