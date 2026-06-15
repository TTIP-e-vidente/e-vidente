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

Auditoría:

`http://localhost:3000/dev/email/deliveries?limit=20`

## 5. Consentimiento de rachas

Los mails `streak_at_risk` y `streak_lost` solo se envían si `users.email_notifications_enabled = true`.

El jugador puede cambiarlo en **Editar perfil** (juego) vía `PATCH /player/me` con `email_notifications_enabled`.

El welcome es transaccional y no depende de ese flag.
