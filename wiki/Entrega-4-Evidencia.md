# Evidencia — Entrega 4

Checklist para demostrar el circuito de mails en revisión TTIP o defensa.

---

## Código y configuración

| Ítem | Dónde | Estado |
|------|-------|--------|
| Módulo email | `BACKEND/src/modules/email/` | Implementado |
| Migraciones | `021_email_notifications.sql`, `022_email_deliveries_audit.sql`, `023_*` | Aplicar con `npm run migrate` |
| Setup Brevo | `BACKEND/docs/BREVO_SETUP.md` | Documentado |
| Variables `.env` | `BACKEND/.env.example` | Documentado |
| Cron local Windows | `scripts/local/register-email-tasks-windows.ps1` | Opcional dev |
| Cron GitHub | `.github/workflows/email-cron.yml` | Requiere `BACKEND_BASE_URL` |

---

## Flujos a demostrar

### A — Bienvenida

1. `EMAIL_ENABLED=true` + Brevo configurado.
2. Registrar usuario con mail desde Godot o `POST /auth/register`.
3. Verificar `GET /dev/email/deliveries?template_key=welcome&status=sent`.

### B — Consentimiento

1. Registrar con checkbox desmarcado → `email_notifications_enabled = false` en DB.
2. `PATCH /player/me` con `{ "email_notifications_enabled": true }` → perfil actualizado.

### C — Racha en riesgo

1. Usuario con racha, `last_activity_day = ayer`, notificaciones ON.
2. `npm run email:streaks` o script local.
3. Mail `streak_at_risk` en deliveries; segundo run mismo día → `skipped` por dedupe.

### D — Racha perdida

1. `last_activity_day <= hoy - 2 días`.
2. Job de rachas → `streak_lost` + `current_count = 0`.

### E — Preview sin enviar

```
GET /dev/email/preview?template_key=welcome&name=Agus&mail=test@example.com
GET /dev/email/preview?template_key=streak_at_risk&name=Agus&streak_count=7
GET /dev/email/preview?template_key=streak_lost&name=Agus&streak_count=12
```

---

## Tests automatizados

```bash
cd BACKEND
npm run test
```

`npm run test` corre migraciones y suites con `NODE_ENV=test` y **sin envío a Brevo** (`EMAIL_ENABLED=false` en el runner). Así no dependés de IP autorizada ni de API key para que pasen auth/player.

Solo templates (unitario, sin red):

```bash
npm run test:email
```

Smoke operativo (config + previews + deliveries; envío opcional):

```bash
npm run smoke:email
# $env:SMOKE_EMAIL_TO="tu@mail.com"; npm run smoke:email -- --send
```

Demo racha en riesgo:

```bash
npm run seed:streak-email-demo
npm run email:streaks
```

### Validación end-to-end (un comando)

Con Docker + `.env` + Brevo configurado:

```bash
npm run validate:email-flow
```

Valida: DB, config, templates, seed de racha, outbox welcome, job outbound y auditoría en `email_deliveries`.  
Limpieza opcional: `npm run validate:email-flow -- --cleanup`.

---

## Tickets Jira (referencia wiki)

| Ticket | Tema |
|--------|------|
| [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64) | Notificaciones email racha en riesgo |
| UNQ-90 | Registro |
| UNQ-27 | Perfil |
| UNQ-149 | Mensaje pérdida racha (in-game) |

---

## Pendiente de evidencia en producción

- [ ] `EMAIL_ENABLED=true` en servidor
- [ ] Remitente `noreply@dominio` verificado (no Gmail)
- [ ] Secrets `BACKEND_BASE_URL` + `EMAIL_CRON_SECRET` en GitHub
- [ ] Captura de mail recibido en bandeja real (Gmail u otro)
- [ ] Query de auditoría con al menos un `provider_message_id` de Brevo
