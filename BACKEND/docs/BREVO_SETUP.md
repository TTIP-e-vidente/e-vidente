# Configuración Brevo (local y producción)

Guía para remitente verificado, rotación de API key y variables de entorno.

## 1. Rotar la API key (obligatorio si se expuso)

Si la key apareció en chat, logs, capturas o commits:

1. Entrá a [Brevo](https://app.brevo.com) → **SMTP & API** → **API Keys**.
2. **Revocá** la key comprometida.
3. Creá una key nueva con permiso **Send emails** (transaccional).
4. Pegala solo en `BACKEND/.env` (nunca en git):

   ```env
   BREVO_API_KEY=xkeysib-...
   ```

5. Reiniciá el backend (`npm run dev`) o volvé a correr los jobs de email.

`BACKEND/.env.example` documenta las variables; **no** incluye la key real.

## 2. Remitente verificado

### IP autorizada (error 401 `unrecognised IP address`)

Si Brevo tiene **Authorized IPs** activo, cada IP desde la que llamás la API debe estar en la lista. En local o con IP dinámica suele fallar con:

```json
{"message":"We have detected you are using an unrecognised IP address ...","code":"unauthorized"}
```

**Opciones:**

| Opción | Cuándo |
|--------|--------|
| Agregar tu IP pública en [Brevo → Security → Authorized IPs](https://app.brevo.com/security/authorised_ips) | Dev estable en una red |
| Desactivar la restricción de IP en Brevo | Dev local / IP que cambia (recomendado para demo) |

Los **tests de integración** (`npm run test`) fuerzan `EMAIL_ENABLED=false` para no llamar a Brevo ni dejar envíos async abiertos.

Para probar envío real: `EMAIL_ENABLED=true` en `.env` y correr `npm run dev` o los scripts `email:*` — no `npm run test`.

En Brevo → **Senders & IP** → **Senders**:

| Campo | Valor recomendado local |
|-------|-------------------------|
| Email | El que uses en `BREVO_SENDER_EMAIL` |
| Nombre | `E-VIDENTE` (`BREVO_SENDER_NAME`) |

El remitente debe figurar como **Verified**. Si no, Brevo rechaza el envío.

### Gmail como remitente (solo dev/demo)

Funciona para pruebas, pero:

- DKIM/DMARC suelen quedar incompletos.
- Mayor riesgo de spam o carpeta Promociones.
- No uses Gmail en producción.

### Producción (recomendado)

1. Dominio propio (ej. `evidente.edu.ar`).
2. En Brevo: autenticar dominio (SPF, DKIM, DMARC según el asistente).
3. Remitente tipo `noreply@tudominio.com`.
4. Actualizar `BREVO_SENDER_EMAIL` en el servidor.

## 3. Variables en `.env`

```env
EMAIL_ENABLED=true
BREVO_API_KEY=           # solo en .env local, nunca commitear
BREVO_SENDER_EMAIL=evidente2026@gmail.com
BREVO_SENDER_NAME=E-VIDENTE
EMAIL_TIMEZONE=America/Argentina/Buenos_Aires
```

Con `EMAIL_ENABLED=false` el backend no llama a Brevo (útil sin red o sin key).

## 4. Verificar que funciona

```bash
cd BACKEND
docker compose up -d
npm run migrate
npm run dev
```

Preview (sin enviar):

`http://localhost:3000/dev/email/preview?template_key=welcome&name=Agus&mail=tu@mail.com`

Jobs locales:

```powershell
powershell -ExecutionPolicy Bypass -File ../scripts/local/run-email-job.ps1 -Job streaks
```

Auditoría (solo desarrollo, `NODE_ENV !== production`):

`http://localhost:3000/dev/email/deliveries?limit=20`

Auditoría en **cualquier entorno** (requiere secreto, no hace falta ngrok):

```bash
curl -s -H "X-Job-Secret: $EMAIL_CRON_SECRET" \
  "http://localhost:3000/internal/email/deliveries?mail=tu@mail.com&template_key=email_verification"
```

También podés filtrar por `userId`, `username`, `status` y `limit`. La respuesta incluye resumen (`pending/sent/failed`), estado OTP del usuario y la lista de `email_deliveries`.

Útil mientras no tengas webhook Brevo público: ves si el backend marcó el OTP como `sent` o `failed` aunque Brevo no te avise del bounce.

## 5. Consentimiento de rachas

Los mails `streak_at_risk` y `streak_lost` solo se envían si `users.email_notifications_enabled = true`.

El jugador puede cambiarlo en **Editar perfil** (juego) vía `PATCH /player/me` con `email_notifications_enabled`.

El welcome es transaccional y no depende de ese flag.
