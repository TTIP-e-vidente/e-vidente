# Outbox de emails y reintentos

Tabla: `email_deliveries` (migraciones 021, 022, 023 y **037**).

## Columnas relevantes

| Columna | Uso |
|---|---|
| `template_key` | `welcome`, `account_verified`, `email_verification`, `streak_at_risk`, `streak_lost`, `mail_changed` |
| `dedupe_key` | `UNIQUE(user_id, template_key, dedupe_key)` — evita duplicados |
| `status` | `pending` → `sent` \| `failed` |
| `attempt_count` | intentos totales |
| `next_attempt_at` | (037) backoff: momento a partir del cual se puede reintentar |
| `last_attempt_at` | (037) último intento real |
| `locked_at` / `locked_by` | (037) claim cooperativo del job que procesa la fila |

## Ciclo de vida

1. **Encolar**: `acquireDeliverySlot` crea la fila `pending` (o retoma una
   `failed` sumando `attempt_count`). Si ya hay `sent`/`pending` con el mismo
   dedupe → skip (idempotencia).
2. **Enviar**: Brevo (`sendTransactionalEmail`). OK → `sent` (limpia lock y
   backoff). Falla → `failed` + `next_attempt_at = now() + backoff`.
3. **Backoff** (fijo, por `attempt_count`): 2.º intento **+10 min**,
   3.º **+1 h**, 4.º+ **+6 h**. Máximo configurable
   `EMAIL_RETRY_MAX_ATTEMPTS` (default 4), ventana `EMAIL_RETRY_MAX_AGE_HOURS`
   (default 48 h).
4. **Retry job** (`retry-failed-emails`, cron 08:00 y 20:00 ART, o
   `npm run email:retry-failed`): claim atómico con
   `FOR UPDATE SKIP LOCKED` + `locked_at/locked_by`; dos jobs concurrentes
   (Express legacy y Edge `internal-job`) nunca procesan la misma fila. Locks
   más viejos que 10 min se consideran de jobs muertos y se retoman.
5. **Pendings colgados**: `expireStalePendingDeliveries` pasa a `failed` los
   `pending` con más de `EMAIL_PENDING_STALE_MINUTES` (15).
6. **Webhook Brevo** (`brevo-webhook`): bounces/blocked/unsubscribe marcan
   `failed` y desactivan `email_notifications_enabled`.

## Mails por dedupe

- `account_verified:{userId}` — mail "Tu correo fue verificado" post-OTP:
  **una sola vez por usuario**, incluso si el confirm se repite.
- `verify:{userId}:{codeId}` — un delivery por código OTP.
- `welcome` — bienvenida legacy (una vez por usuario).
- `at_risk:{day}` / `lost:{day}` — rachas, uno por día.

## Tests

- `tests/email.account-verified.integration.test.ts` — dedupe del account_verified.
- `tests/email.retry-job.integration.test.ts` — backoff, claim con lock y agotamiento.
- `tests/email.jobs.integration.test.ts` — jobs de racha (existente).

## Operación

- Estado: `npm run platform:doctor` (sección `outbox`).
- Listado dev: `GET /dev/email/deliveries` (Express, solo development).
