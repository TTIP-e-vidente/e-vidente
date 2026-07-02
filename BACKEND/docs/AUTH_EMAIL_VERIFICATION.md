# Auth y verificación de email (Platform V1)

Contratos de tipos: `src/shared/contracts/api-contracts.ts` (espejo Deno en
`supabase/functions/_shared/contracts.ts`).

## Arquitectura

- La sesión es un **JWT propio** (HS256, `JWT_SECRET`), NO Supabase Auth.
- Producción/staging: Supabase **Edge Functions** (`auth-register`, `auth-login`,
  `auth-me`, `verify-email-request`, `verify-email-confirm`, `player-email-status`).
- Express es legacy y mantiene paridad para los tests locales (`npm test`).
- El OTP es propio: `email_verification_codes` (hash SHA-256, expira 15 min,
  máx. 5 intentos, cooldown de reenvío 120 s).

## Flujo de registro

1. Godot → `POST auth-register` `{username, name, mail, password, birth_date, ...}`.
2. Se crea el usuario (`users`, bcrypt) y se envía el código OTP de 6 dígitos
   (tracked en `email_deliveries`, template `email_verification`).
3. Respuesta 201: `{user, accessToken, verification: {code_send_status, cooldown_seconds, ...}}`.
4. Godot muestra `EmailVerification.tscn` (6 slots de dígitos).

## Login solo con mail verificado

`auth-login` con password correcta pero `mail_verified_at IS NULL` responde:

```json
HTTP 403
{
  "error": "Tenés que verificar tu correo antes de iniciar sesión.",
  "code": "EMAIL_NOT_VERIFIED",
  "user": { ... },
  "verification": { "code_send_status": "sent", "cooldown_seconds": 120, ... },
  "verification_token": "<jwt scope=email_verification>"
}
```

- El código OTP se **(re)envía automáticamente** en ese login (respeta cooldown).
- `verification_token` es un JWT **acotado** (claim `scope: "email_verification"`):
  solo lo aceptan `verify-email-request`, `verify-email-confirm` y
  `player-email-status`. El resto de la API lo rechaza con 401.
- Credenciales inválidas siguen respondiendo 401 `INVALID_CREDENTIALS` sin
  revelar si el usuario existe.
- Cuentas legacy sin mail: login normal (no hay nada que verificar).

## Confirmación del código

`POST verify-email-confirm` `{code: "123456"}` con Bearer (token completo o acotado):

- OK → `{status: "verified", mail_verified_at, accessToken}`. El `accessToken`
  es una **sesión completa**: si el cliente venía con el token acotado, lo
  reemplaza y continúa (Godot: `BackendSession._establecer_sesion_post_verificacion`).
- Tras verificar se encola el mail **`account_verified`** ("Tu correo fue
  verificado"), vía outbox con dedupe `account_verified:{userId}` — una sola vez
  por usuario, con retry si Brevo falla (ver `EMAIL_OUTBOX_AND_RETRIES.md`).
  El fallo del mail nunca bloquea la respuesta del confirm.
- Errores: `INVALID_CODE` (422, con `attempts_remaining`), `CODE_EXPIRED` (422),
  `TOO_MANY_ATTEMPTS` (429, invalida el código), `MAIL_OUT_OF_SYNC` (409),
  `NO_PENDING_CODE` (422).

## Cliente Godot

- `Login.gd`: ante `requiere_verificacion` (403) emite
  `verificacion_escena_solicitada(false, result)` y los handlers
  (`intro.gd`, `AuthLoginOverlayHelper.gd`) abren la verificación en modo
  **obligatorio** (`EmailVerificationBridge.iniciar_pendiente(true, nav)`).
- `BackendSession` guarda el token acotado en `_verificacion_login_pendiente`
  y lo usa para request/confirm/status; al confirmar, cambia a sesión completa,
  emite `login_succeeded` y dispara `cargar_datos_online()`.
- `RemoteErrorMapper.gd` normaliza códigos legacy → canónicos y mensajes es-AR.

## Tests

- `tests/auth.integration.test.ts` — registro, 403 sin verificar, login OK tras verificar.
- `tests/auth.login-unverified.integration.test.ts` — flujo completo del token
  acotado: 403 → status → confirm → accessToken completo → login desbloqueado.
- `tests/profile-mail-verification.integration.test.ts` — cambio de mail + OTP.
- Godot: `juego/tests/backend/test_platform_v1_cliente.gd` (mapper de errores).

## Cómo probar manualmente

1. `npm run dev` (o staging con Edge) + Godot con `backend.local.json` apuntando al stack.
2. Crear cuenta desde Godot → llega el mail con OTP.
3. Cerrar el juego SIN verificar. Reabrir → login → aparece la pantalla de
   código en modo obligatorio (sin "Omitir").
4. Ingresar el código → mail "Tu correo fue verificado" + entra al juego con
   progreso sincronizado.
