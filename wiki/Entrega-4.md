# Entrega 4 — E-VIDENTE

## Qué se agrega o modifica

- **Emails transaccionales (Brevo)** — módulo backend con templates versionados, auditoría en PostgreSQL y jobs programados para rachas.
- **Consentimiento del jugador** — opt-in/opt-out de recordatorios por mail en registro y perfil (`email_notifications_enabled`).
- **Integración juego ↔ backend** — registro envía `accept_email_notifications`; perfil sincroniza la preferencia vía `PATCH /player/me`.
- **Operación local y cloud** — scripts de cron local (Windows / npm), workflow de GitHub Actions cuando haya backend público.
- **Redacción y diseño** — mails alineados a la UI del juego (Rubik, paleta verde/crema); guía de copy en [Mails](Entrega-4-Mails).

## Desafíos técnicos

- Evitar duplicados de envío ante reintentos o caídas de red (`email_deliveries` + `dedupe_key` + estado `pending`).
- Respetar consentimiento sin bloquear mails transaccionales (bienvenida vs recordatorios de racha).
- Alinear el “día de racha” con `EMAIL_TIMEZONE` (ART) y la actividad registrada en PostgreSQL.
- Activar Brevo en producción sin exponer API keys ni enviar desde entornos de desarrollo por error (`EMAIL_ENABLED`).

## Alcance de Entrega 4

| Bloque | Resultado | Estado |
|--------|-----------|--------|
| Módulo email (Brevo) | Cliente API, service, repository, templates | Listo |
| Mail de bienvenida | Async post-registro, sin bloquear 201 | Listo |
| Racha en riesgo | Cron diario 19:00 ART, SQL de candidatos | Listo |
| Racha perdida | Mail + reset de `current_count` post-envío | Listo |
| Reintento de fallidos | Job 08:00 y 20:00 ART | Listo |
| Consentimiento UI | Login + perfil (Godot) | Listo |
| Auditoría | Tabla `email_deliveries` + endpoints dev | Listo |
| Copy y guía editorial | Documentación en wiki | En curso |
| Activación producción | `EMAIL_ENABLED=true` + dominio verificado | Pendiente |
| Tests integración jobs | Candidatos SQL + dedupe | Pendiente |

### Fuera de alcance

- Verificación de email (link de confirmación de cuenta).
- Recuperación de contraseña por mail.
- Newsletters o campañas masivas de marketing.
- Push notifications nativas (solo mail en esta entrega).

## Documentación

- [User Stories](Entrega-4-User-Stories)
- [Arquitectura](Entrega-4-Arquitectura)
- [Mails — redacción y operación](Entrega-4-Mails)
- [Decisiones](Entrega-4-Decisiones)
- [Evidencia](Entrega-4-Evidencia)

### Referencia técnica en código

- `BACKEND/src/modules/email/README.md`
- `BACKEND/docs/BREVO_SETUP.md`
- `juego/niveles/progress/README.md` (tabla evento in-game ↔ mail)
