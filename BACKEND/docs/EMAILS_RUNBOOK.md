# Runbook: "no llegan los mails"

Checklist en orden. La infraestructura marca cada envío en `email_deliveries`
(`sent` = Brevo lo aceptó con messageId), así que primero mirá los datos antes
de tocar código.

## 1. Diagnóstico en un comando

```bash
cd BACKEND
npm run platform:doctor:staging
```

- `outbox` muestra sent/pending/failed. `failed>0` → correr
  `npm run email:retry-failed` o esperar el cron (08:00/20:00 ART).
- `cron` > 90 min sin invocaciones → pg_cron caído: `npm run setup:supabase:cron`
  y revisar `SELECT * FROM private.cron_invocation_log ORDER BY created_at DESC LIMIT 5;`.

## 2. Mails de racha que "no llegan" — causas reales (por frecuencia)

1. **El usuario tiene las notificaciones apagadas** (`email_notifications_enabled=false`).
   El job lo excluye por diseño. Hasta 2026-07-01 el registro de Godot mandaba
   `accept_email_notifications=false` hardcodeado → TODOS los usuarios viejos
   están apagados. Se activa desde el perfil del juego, o por SQL:
   `UPDATE users SET email_notifications_enabled = true WHERE username = '...';`
2. **El mail no está verificado** (`mail_verified_at IS NULL`). El job también
   lo excluye. Ahora el login obliga a verificar, así que esto se corrige solo.
3. **El usuario jugó hoy.** `streak-at-risk` (18:00 ART) solo avisa a quien
   jugó AYER y hoy todavía no. Si jugás todos los días antes de las 18:00,
   nunca te llega — es correcto.
4. **Cae a spam.** El sender es `evidente2026@gmail.com` vía Brevo: Gmail
   penaliza SPF/DKIM desalineados. El doctor lo marca con WARN. Solución de
   fondo: verificar un dominio propio en Brevo (Senders & Domains) y cambiar
   `BREVO_SENDER_EMAIL`. Mientras tanto: revisar spam y marcar "no es spam".

## 3. Mails de verificación (OTP)

- **Contra Supabase**: `npm run smoke:verify-email-edge` (envía y valida cooldown)
  y `npm run smoke:brevo-edge` (Brevo accesible desde Edge). Si cambiaste código
  de Edge: `npm run supabase:functions:deploy` — **el código local NO corre en
  Supabase hasta deployar**.
- **Local (`npm run dev`)**: si `.env` tiene `BREVO_API_KEY`, el mail sale real;
  si no, el código aparece en la consola del backend (buscar `dev_code`). No es
  un bug: es el modo desarrollo.
- Estado por usuario: `GET player-email-status` o
  `SELECT * FROM email_verification_codes WHERE user_id=... ORDER BY created_at DESC;`

## 4. Ver qué pasó con un mail puntual

```sql
SELECT template_key, status, attempt_count, error_message, created_at, sent_at
FROM email_deliveries
WHERE recipient_email = 'usuario@mail.com'
ORDER BY created_at DESC;
```

- `sent` + sin llegar → problema de entregabilidad (spam/DMARC), mirar el log
  de Brevo (dashboard → Transactional → Logs) con el `provider_message_id`.
- `failed` → `error_message` dice por qué; el retry job lo reintenta con
  backoff (+10 min, +1 h, +6 h; máx 4 intentos).
- `pending` viejo → lo expira el job (15 min) y pasa a failed/retry.
- No hay fila → el envío nunca se intentó: usuario filtrado (punto 2) o
  EMAIL_ENABLED off.

## 5. El mail llega pero sin logo / sin íconos

Causa: `resolveLogoSrc()`/`resolveIconSrc()` en
`supabase/functions/_shared/email/email-assets.ts` mandan las imágenes en
`data:image/png;base64,...` embebido en el HTML cuando no hay
`EMAIL_LOGO_URL`/`EMAIL_ASSETS_BASE_URL` configurados. Ese fallback existe
solo para previews locales — **Brevo y la mayoría de los clientes de mail
(Gmail incluido) no renderizan imágenes base64 inline**, así que el mail
llega pero con el logo y los íconos vacíos/rotos.

Fix (fuente de verdad: bucket público `email-assets` en Supabase Storage):

```bash
cd BACKEND
npm run sync:email-assets:storage   # sube logo.png + icons/*.png al bucket
npm run supabase:functions:deploy   # ya corre el sync de arriba + empuja los secrets
```

- `EMAIL_LOGO_URL` y `EMAIL_ASSETS_BASE_URL` viven en `BACKEND/.env.staging`
  (fuente de verdad) y se empujan como secrets de Edge Functions vía
  `setup-supabase-functions.ts`. Si cambiás `logo.png` o cualquier ícono en
  `BACKEND/src/modules/email/assets/`, corré `sync:email-assets:storage` — si
  no, el bucket queda desactualizado sin ningún error visible.
- `npm run check:deploy:staging` (o `:production`) ahora falla si faltan esas
  variables o si la URL del logo no responde 200.
- `validateEdgeFunctionSecrets()` en `scripts/lib/supabase-edge-secrets.ts`
  las exige cuando `EMAIL_ENABLED=true`, así que
  `npm run supabase:functions:deploy` no deja pushear secrets incompletos.

## 6. Validación end-to-end (después de cambios)

```bash
npm test                              # suite completa local
npm run smoke:auth-edge               # login bloqueado sin verificar + token acotado
npm run smoke:verify-email-edge       # OTP por Edge
npm run smoke:brevo-edge              # Brevo desde Edge
npm run platform:doctor:staging       # estado general
```
