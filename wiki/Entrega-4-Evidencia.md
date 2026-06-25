# Evidencia — Entrega 4

Checklist, comandos y guía de demostración para revisión TTIP. Diseñado para copiar-pegar en la defensa.

**Inicio rápido:** [Guía 5 min](Entrega-4-Guia-Rapida) · [Resumen](Entrega-4) · [User Stories](Entrega-4-User-Stories) · [Mails](Entrega-4-Mails)

---

## Evidencia por user story

| US | Descripción | Tickets | Cómo validar | Estado |
|----|-------------|---------|--------------|--------|
| US-01 | Verificar mail OTP | UNQ-90, UNQ-27 | `smoke:email-verification` · Godot | ✅ |
| US-02 | Bienvenida post-OTP | UNQ-64, UNQ-90 | deliveries `welcome` | ✅ |
| US-03 | Consentimiento | UNQ-64, UNQ-27 | Registro + perfil | ✅ |
| US-04 | Racha en riesgo | [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64), UNQ-83 | `seed:streak-email-demo` | ✅ |
| US-05 | Racha perdida | UNQ-64, UNQ-149 | Job + reconcile + panel | ✅ |
| US-06 | Aviso cambio mail | UNQ-27 | Template `mail_changed` | ✅ |
| US-07 | Ops y auditoría | — | `/dev/email/*`, jobs | ✅ |

---

## Tickets Jira

| Clave | Resumen | US |
|-------|---------|-----|
| [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64) | Notificaciones email racha | US-02–05 |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Registro de usuario | US-01, US-02 |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Perfil de usuario | US-01, US-03, US-06 |
| [UNQ-149](https://tip-unq.atlassian.net/browse/UNQ-149) | Mensaje pérdida racha in-game | US-05 |
| UNQ-83 | Indicador visual racha | US-04 (complemento) |

---

## Resultados de validación registrados

| Fecha | Comando | Resultado |
|-------|---------|-----------|
| Jun 2026 | `npm run validate:email-flow` | ✅ Circuito E2E local con Brevo |
| 2026-06-25 | `npm run test:email` | ✅ 5 templates OK + `messageId` Brevo en los 5 envíos |

Templates validados con envío real (jun 2026):

| Template | `provider_message_id` (ejemplo) |
|----------|--------------------------------|
| `email_verification` | `@smtp-relay.mailin.fr` |
| `welcome` | `@smtp-relay.mailin.fr` |
| `streak_at_risk` | `@smtp-relay.mailin.fr` |
| `streak_lost` | `@smtp-relay.mailin.fr` |
| `mail_changed` | `@smtp-relay.mailin.fr` |

> Los IDs completos quedan en `email_deliveries` tras cada run. Query abajo.

---

## Evidencia técnica en código

| Bloque | Archivos | Comando / acción |
|--------|----------|------------------|
| Módulo email | `BACKEND/src/modules/email/` | `npm run test:email` |
| OTP backend | `email.verification.service.ts` | `npm run smoke:email-verification` |
| OTP Godot | `juego/interface/auth/EmailVerification*` | F5 → verificar mail |
| Consentimiento | `auth.gd`, `Login.tscn` | Checkbox + toggle perfil |
| Jobs racha | `email.jobs.routes.ts` | `npm run email:streaks` |
| Auditoría | `email.repository.ts` | `GET /dev/email/deliveries` |
| Cron cloud | `.github/workflows/email-cron.yml` | Manual dispatch / schedule |
| Cron local | `scripts/local/*.ps1` | Task Scheduler |
| E2E | `scripts/validate-email-flow.ts` | Un comando |

---

## Demo TTIP (~15 minutos)

| # | Qué mostrar | Acción |
|---|-------------|--------|
| 1 | 5 previews HTML | URLs sección [Preview](#e--preview-sin-enviar) |
| 2 | Registro + opt-in | Godot Intro → Registro |
| 3 | OTP en bandeja | Mail `email_verification` |
| 4 | Verificar en juego | Pantalla OTP → `mail_verified_at` |
| 5 | Bienvenida | Mail `welcome` + deliveries |
| 6 | Toggle perfil | Desactivar/activar recordatorios |
| 7 | Racha demo | `npm run seed:streak-email-demo -- --run-job` |
| 8 | Dedupe | Segundo `npm run email:streaks` → `skipped` |
| 9 | In-game | `StreakLossMessagePanel` |
| 10 | Auditoría | Query SQL o `/dev/email/deliveries` |

**Guión hablado sugerido:** “Mostramos que Godot nunca toca Brevo; el backend audita cada envío; si el cron corre dos veces no duplica; y la racha se reconcilia aunque falle el proveedor.”

---

## Endpoints útiles (dev)

Base: `http://localhost:3000` (ajustar puerto según `.env`).

| Método | Ruta | Uso |
|--------|------|-----|
| GET | `/dev/email/templates` | Catálogo de 5 templates |
| GET | `/dev/email/preview?template_key=...` | HTML sin enviar |
| GET | `/dev/email/deliveries?limit=20` | Auditoría |
| GET | `/dev/email/deliveries?template_key=welcome&status=sent` | Filtrar |
| POST | `/player/verify-email/request` | Solicitar OTP (auth) |
| POST | `/player/verify-email/confirm` | Confirmar OTP (auth) |
| POST | `/internal/jobs/streak-emails` | Job rachas (`X-Job-Secret`) |
| POST | `/internal/jobs/retry-failed-emails` | Retry (`X-Job-Secret`) |

### Ejemplos curl

```bash
# Catálogo templates
curl -s "http://localhost:3000/dev/email/templates" | jq .

# Últimas entregas
curl -s "http://localhost:3000/dev/email/deliveries?limit=5" | jq .

# Preview bienvenida (abrir HTML en browser)
curl -s "http://localhost:3000/dev/email/preview?template_key=welcome&name=Agus&mail=demo@test.com"

# Job rachas (reemplazar SECRET)
curl -X POST "http://localhost:3000/internal/jobs/streak-emails" \
  -H "X-Job-Secret: $EMAIL_CRON_SECRET"
```

---

## Flujos detallados

### A — Verificación OTP

1. `EMAIL_ENABLED=true` + Brevo en `.env`.
2. Registro con mail (Godot o `POST /auth/register`).
3. `POST /player/verify-email/request` → mail 6 dígitos.
4. Confirmar en Godot → `mail_verified_at` poblado.

### B — Bienvenida

1. Solo **después** de confirmar OTP.
2. `GET /dev/email/deliveries?template_key=welcome&status=sent`.
3. Reintento → dedupe, sin segundo mail.

### C — Consentimiento

1. Registro con checkbox off → `email_notifications_enabled = false`.
2. `PATCH /player/me` `{ "email_notifications_enabled": true }`.
3. Sin mail verificado → UI bloquea activar recordatorios.

### D — Racha en riesgo

1. Mail verificado + notificaciones ON + `last_activity_day = ayer`.
2. `npm run seed:streak-email-demo -- --run-job`.
3. Segundo run mismo día → status `skipped` en dedupe.

### E — Preview sin enviar

```
/dev/email/preview?template_key=email_verification&name=Agus&mail=test@example.com
/dev/email/preview?template_key=welcome&name=Agus&mail=test@example.com
/dev/email/preview?template_key=streak_at_risk&name=Agus&streak_count=7
/dev/email/preview?template_key=streak_lost&name=Agus&streak_count=12
/dev/email/preview?template_key=mail_changed&name=Agus
```

### F — Racha perdida

1. `last_activity_day <= hoy - 2`.
2. Job → `streak_lost` + `current_count = 0` en DB.

---

## Tests automatizados

```bash
cd BACKEND
docker compose up -d
npm run migrate
npm run test
```

Suites email incluidas:

| Archivo | Cubre |
|---------|-------|
| `email.templates.unit.test.ts` | 5 templates, escape HTML |
| `email.jobs.integration.test.ts` | Candidatos, dedupe, reconcile |
| `email.internal.integration.test.ts` | Jobs 401 sin secret |
| `email.webhook.integration.test.ts` | Auditoría webhook |

Rápido (sin Docker para unitarios de template):

```bash
npm run test:email
```

E2E completo:

```bash
npm run validate:email-flow
npm run validate:email-flow -- --cleanup   # limpiar datos demo
```

---

## Checklist revisión TTIP

### Implementación

- [x] 5 templates + módulo email
- [x] Migraciones `021`–`024`, `028`
- [x] Tests `npm run test` (con Postgres)
- [x] Copy wiki alineado al código
- [x] OTP backend + Godot
- [x] Consentimiento registro + perfil
- [x] UNQ-149 in-game
- [x] `validate:email-flow` jun 2026
- [x] `test:email` 5/5 con Brevo (2026-06-25)

### Evidencia visual (pegar capturas abajo)

- [ ] OTP en bandeja
- [ ] Bienvenida
- [ ] Racha en riesgo o perdida
- [ ] `/dev/email/deliveries` con `provider_message_id`
- [ ] UI verificación Godot
- [ ] (Opcional) Task Scheduler

### Producción

- [ ] `EMAIL_ENABLED=true` en servidor
- [ ] Dominio verificado SPF/DKIM
- [ ] Secrets GitHub Actions
- [ ] Primer envío prod auditado

---

## Queries SQL (demo en vivo)

Últimos envíos:

```sql
SELECT template_key, status, recipient_email,
       provider_message_id, created_at
FROM email_deliveries
ORDER BY created_at DESC
LIMIT 10;
```

Resumen por template:

```sql
SELECT template_key, status, COUNT(*) AS n
FROM email_deliveries
GROUP BY template_key, status
ORDER BY 1, 2;
```

Usuario demo racha:

```sql
SELECT u.username, u.mail_verified_at, u.email_notifications_enabled,
       s.current_count, s.last_activity_day
FROM users u
JOIN streaks s ON s.user_id = u.id
WHERE u.username = 'streak_demo';
```

---

## Evidencia visual

Subí capturas a GitHub (issue/PR) y pegá los links. Formato:

<!-- Reemplazar URLs cuando estén disponibles -->

| Captura | Estado |
|---------|--------|
| OTP en bandeja Gmail | Pendiente |
| Mail bienvenida | Pendiente |
| streak_at_risk / streak_lost | Pendiente |
| Endpoint deliveries JSON | Pendiente |
| Pantalla verificación Godot | Pendiente |

Ejemplo cuando tengas la URL:

```html
<img width="460" alt="OTP verificación" src="https://github.com/user-attachments/assets/..." />
```

Referencia de formato: [Entrega-3-Evidencia](Entrega-3-Evidencia).
