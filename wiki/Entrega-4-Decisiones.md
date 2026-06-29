# Decisiones — Entrega 4

Architecture Decision Records (ADRs) del circuito de mails. [Resumen](Entrega-4) · [Arquitectura](Entrega-4-Arquitectura)

---

## Contexto

Cerrar [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64) sin acoplar Godot a Brevo, con mail verificado, consentimiento explícito y trazabilidad en Postgres.

---

## ADR-01 — Brevo como proveedor transaccional

**Decisión:** API REST de Brevo (`/v3/smtp/email`), no SMTP directo desde el backend.

**Motivo:** Dashboard de entregas, tier free usable, integración simple con Node.

**Consecuencias:** `BREVO_API_KEY` solo en servidor; dominio propio recomendado en prod.

---

## ADR-02 — Templates versionados en TypeScript

**Decisión:** Copy y HTML en `templates/*.ts` dentro del repo, no en Brevo UI.

**Motivo:** Mismo PR para copy + lógica; preview en dev; tests unitarios.

**Consecuencias:** Cambios editoriales pasan por code review. Editor visual queda para el futuro.

---

## ADR-03 — `EMAIL_ENABLED` como interruptor maestro

**Decisión:** Default `false` en `.env.example`; sin key no hay envíos.

**Motivo:** Evitar mails accidentales en CI y laptops de dev.

**Consecuencias:** Activación explícita en deploy productivo.

---

## ADR-04 — OTP antes de bienvenida y recordatorios

**Decisión:** Código 6 dígitos en juego; bienvenida solo tras `mail_verified_at`.

**Motivo:** Mails a direcciones typo no verificadas; base para opt-in confiable.

**Consecuencias:** UI Godot dedicada; dos mails en onboarding (OTP + welcome).

---

## ADR-05 — Consentimiento separado de transaccional

**Decisión:** OTP, welcome y `mail_changed` ignoran `email_notifications_enabled`. Rachas lo requieren.

**Motivo:** Cumplimiento de buenas prácticas; transaccional ≠ marketing de hábito.

**Consecuencias:** Opt-out visible en cada mail de racha.

---

## ADR-06 — Dedupe en `email_deliveries`

**Decisión:** `dedupe_key` único por usuario/evento/día; estado `pending` bloquea duplicados.

**Motivo:** Cron duplicado, retries HTTP y re-ejecución manual sin spam.

**Consecuencias:** Tests de integración obligatorios para jobs.

---

## ADR-07 — Reconcile de racha independiente del mail

**Decisión:** `reconcileExpiredStreaksInDatabase` corre aunque falle Brevo.

**Motivo:** Consistencia servidor > entrega de notificación.

**Consecuencias:** Jugador puede perder racha en DB sin recibir mail (edge case aceptado).

---

## ADR-08 — Godot no integra Brevo

**Decisión:** Solo REST al backend (`AuthApi`, verificación, perfil).

**Motivo:** Separación de responsabilidades; secretos solo en servidor.

**Consecuencias:** Todo envío auditable centralmente.

---

## ADR-09 — Cron 19:00 ART + timezone única

**Decisión:** `EMAIL_TIMEZONE=America/Argentina/Buenos_Aires`; job principal antes de medianoche local.

**Motivo:** Equipo y demo en Argentina; ventana razonable para “jugá hoy”.

**Consecuencias:** Jugadores en otras zonas: mejora futura (ADR pendiente).

---

## ADR-10 — Outbox async para welcome

**Decisión:** Encolar en `email_deliveries` pending; procesar con startup o job outbound.

**Motivo:** No bloquear respuesta HTTP de confirm OTP (201 rápido).

**Consecuencias:** Welcome puede llegar segundos después de verificar.

---

## Alternativas descartadas

| Alternativa | Por qué no |
|-------------|------------|
| Godot → Brevo directo | Expone API key |
| Bienvenida al registro sin OTP | Mails a cuentas inválidas |
| Link mágico vs OTP | Godot no es browser; OTP copiable en mobile |
| Un mail genérico de racha | Peor UX y conversión |
| Sin dedupe | Duplicados en cada retry |

---

## Roadmap de decisiones

| # | Tema | Estado |
|---|------|--------|
| 1 | Módulo backend | ✅ Hecho |
| 2 | Wiki + copy | ✅ Hecho |
| 3 | OTP + Godot | ✅ Hecho |
| 4 | Tests integración | ✅ Hecho |
| 5 | E2E `validate:email-flow` | ✅ Hecho |
| 6 | Producción + dominio | ⏳ Pendiente |
| 7 | Recuperación contraseña por mail | 🔜 E5 candidato |

Ver [Bitácora E4](Bitacora-Entrega-4).
