# Arquitectura — Entrega 4 (emails)

## Qué cambió respecto a Entrega 3

Entrega 3 dejó el backend, la racha en PostgreSQL y el consentimiento en `users`, pero **sin envío real de correos**. Entrega 4 cierra el circuito: el backend puede notificar por mail sin acoplar Godot a Brevo.

Regla de oro: **Godot nunca habla con Brevo**. Solo persiste preferencias y dispara eventos de negocio (registro); el backend orquesta el envío.

---

## Vista general

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTE (Godot)                          │
│  Login / auth.gd  →  accept_email_notifications                 │
│  Perfil           →  PATCH email_notifications_enabled          │
│  HUD / StreakLoss →  feedback in-game (paralelo al mail)        │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP (AuthApi, BackendSession)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BACKEND (Node / Express)                    │
│  auth.service      → queueWelcomeEmail()                        │
│  email.service     → deliverTrackedEmail()                      │
│  email.repository  → candidatos SQL + dedupe                    │
│  email.client      → POST api.brevo.com/v3/smtp/email           │
└────────────┬───────────────────────────────┬────────────────────┘
             │                               │
             ▼                               ▼
      PostgreSQL                      Brevo (SMTP API)
  users, streaks,                 remitente verificado
  email_deliveries                messageId transaccional
```

---

## Módulo `BACKEND/src/modules/email/`

| Archivo | Responsabilidad |
|---------|-----------------|
| `email.client.ts` | HTTP a Brevo; payload sender/to/subject/html/text |
| `email.config.ts` | `EMAIL_ENABLED`, keys, timezone, concurrencia, retry |
| `email.service.ts` | Orquestación: welcome, rachas, retry, preview dev |
| `email.repository.ts` | SQL: candidatos, `acquireDeliverySlot`, auditoría |
| `email.jobs.routes.ts` | `POST /internal/jobs/streak-emails` y `retry-failed-emails` |
| `email.routes.ts` | Dev: preview, listado de deliveries, catálogo templates |
| `templates/*.ts` | Copy + HTML; registry en `templates/index.ts` |

---

## Tipos de mail y disparadores

| `template_key` | Disparador | Consentimiento | Dedupe |
|----------------|------------|----------------|--------|
| `welcome` | Registro con `mail` no vacío | No (transaccional) | `welcome` por usuario |
| `streak_at_risk` | Cron 19:00 ART | Sí (`email_notifications_enabled`) | `at_risk:YYYY-MM-DD` |
| `streak_lost` | Mismo cron | Sí | `lost:YYYY-MM-DD` del último día activo |

### Criterio SQL — racha en riesgo

Jugó **ayer**, hoy **sin** actividad registrada, racha `current_count > 0`, mail presente, notificaciones activas.

### Criterio SQL — racha perdida

Última actividad **hace 2+ días**, misma racha activa en DB. Tras el job: mail `streak_lost` (si consentimiento) y `reconcileExpiredStreaksInDatabase` resetea `current_count → 0`.

---

## Flujo de un envío (auditoría)

```
1. acquireDeliverySlot (TX)
   → INSERT pending o reintento sobre failed
   → skip si ya hay sent/pending con mismo dedupe

2. sendTransactionalEmail (Brevo)
   → provider_message_id

3. markDeliverySent (TX)
   → status = sent
   → afterSent opcional (welcome_email_sent_at, reset racha)

Si falla Brevo:
   → markDeliveryFailed + error_message
   → job retry-failed reprocesa dentro de ventana configurada
```

Estados en `email_deliveries`: `pending` → `sent` | `failed`. Los `pending` viejos (> 15 min por defecto) expiran a `failed`.

---

## Cron y entornos

| Entorno | Mecanismo | Cuándo |
|---------|-----------|--------|
| Dev local | `scripts/local/run-email-job.ps1` o Task Scheduler | 19:00 / 08:00 / 20:00 ART |
| Backend levantado | `npm run email:streaks` o POST interno con `X-Job-Secret` | Manual o scheduler |
| Producción | `.github/workflows/email-cron.yml` → `BACKEND_BASE_URL` | Mismo horario ART |

`EMAIL_ENABLED=false` corta **toda** llamada a Brevo (útil en CI o sin key).

---

## Relación in-game ↔ mail

| Evento | Godot | Email |
|--------|-------|-------|
| Racha en riesgo | Badge warning en HUD | `streak_at_risk` |
| Racha perdida | `StreakLossMessagePanel` | `streak_lost` |
| Registro | Hint en formulario | `welcome` |

El mail **complementa** la experiencia in-game; no la reemplaza. Un jugador offline o sin consentimiento sigue viendo feedback local.

---

## Variables de entorno (resumen)

Ver `BACKEND/.env.example` y `BACKEND/docs/BREVO_SETUP.md`.

| Variable | Rol |
|----------|-----|
| `EMAIL_ENABLED` | Master switch |
| `BREVO_API_KEY` | Autenticación API |
| `BREVO_SENDER_EMAIL` / `BREVO_SENDER_NAME` | Remitente verificado |
| `EMAIL_TIMEZONE` | Fecha “hoy” para candidatos (default ART) |
| `EMAIL_CRON_SECRET` | Protege jobs HTTP internos |
| `EMAIL_BATCH_CONCURRENCY` | Paralelismo de envío (default 5) |

---

## Cómo extender (nuevo template)

1. Crear `templates/mi-template.template.ts` con `buildMiTemplate(context)`.
2. Registrar en `templates/index.ts` (metadata + sample).
3. Agregar disparador en `email.service.ts` (o job dedicado).
4. Migración solo si hace falta nuevo índice o columna (evitar tocar migraciones ya aplicadas).
5. Preview: `GET /dev/email/preview?template_key=...`
6. Test: `npm run test:email`
7. Documentar copy en [Entrega-4-Mails](Entrega-4-Mails).

---

## Lo que queda para después

- Deploy productivo con dominio propio (SPF/DKIM/DMARC).
- Test de integración del job de rachas contra Postgres de prueba.
- Mail de recuperación de contraseña (Entrega futura).
