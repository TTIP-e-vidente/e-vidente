# Bitácora — Entrega 4

Diario de la entrega de **emails transaccionales, verificación OTP y recordatorios de racha**. Entradas **más nuevas arriba**.

---

### `2026-06-25` — Documentación E4 nivel producción
<kbd>Docs</kbd> <kbd>TTIP</kbd>

Segunda pasada de documentación: guía rápida para revisores, flujo E3→E4, ADRs numerados, endpoints API, evidencia con resultados de `test:email` y próximos pasos post-E4.

**Qué se agregó**
- `Entrega-4-Guia-Rapida.md`, `Entrega-4-Flujo-E3-E4.md`, `Entrega-4-Proximos-Pasos.md`
- Tablas npm, curl, SQL y cron en Arquitectura/Evidencia
- Enlaces desde README raíz, Entrega 3 y `BACKEND/email/README`

**Impacto**
- Revisor TTIP puede validar en 5 min sin leer todo el repo.

**Evidencia técnica**
- `wiki/Entrega-4*.md`, `wiki/Entregas.md`

---

### `2026-06-25` — Cierre documental Entrega 4
<kbd>Docs</kbd> <kbd>TTIP</kbd>

Se consolidó la wiki E4: alcance actualizado (5 templates), bitácora propia, evidencia por US y alineación entre código, copy y flujos Godot.

**Qué se documentó**
- Verificación OTP + bienvenida post-confirmación (no al registro).
- Tabla US ↔ tickets ↔ comandos de validación.
- Índices `Entregas.md` y `Bitacora.md` apuntando a E4.

**Impacto para el equipo**
- Una sola fuente de verdad para demo TTIP y defensa.
- Sin contradicciones entre User Stories y `Entrega-4-Mails.md`.

**Evidencia técnica**
- `wiki/Entrega-4*.md`, `wiki/Bitacora-Entrega-4.md`

---

### `2026-06-24` — Assets visuales y polish de templates
<kbd>Email</kbd> <kbd>UX</kbd>

Se publicaron íconos y logo embebidos en HTML de mails (Rubik, paleta verde/crema, cards alineadas al juego).

**Qué se implementó**
- `BACKEND/src/modules/email/assets/` + `copy-email-assets.cjs`
- Íconos por template: welcome, mail, streak, security, alert
- CTAs de bienvenida (jugar + ranking) vía `EMAIL_APP_PLAY_URL`

**Impacto para el jugador**
- Mails legibles en Gmail y móvil, coherentes con la identidad visual del juego.

**Evidencia técnica**
- Commit `c40f99e` — Publica assets de emails
- `templates/layout.ts`, `templates/email-icons.ts`

---

### `2026-06-23` — Verificación OTP end-to-end (backend + Godot)
<kbd>Email</kbd> <kbd>Godot</kbd> <kbd>Auth</kbd>

Se cerró el circuito de mail verificado: OTP al registrarse o cambiar mail, bienvenida solo tras confirmar.

**Qué se implementó**
- `POST /player/verify-email/request` y `/confirm`
- Tabla `email_verification_codes` + límites de intentos
- UI Godot: `EmailVerification.tscn`, `EmailVerificationService.gd`
- Template `email_verification` y aviso `mail_changed` al mail anterior
- Smoke `npm run smoke:email-verification`

**Impacto para el jugador**
- Confianza en la cuenta; recordatorios de racha solo con mail válido.
- Flujo claro: código → verificar → bienvenida.

**Evidencia técnica**
- Commits `8647176`, `8c5cf75`, `e5acdfe`, `0c8e813`
- `migrations/024_email_verification.sql`, `028_email_verification_attempts.sql`
- `juego/interface/auth/EmailVerification*.gd`

---

### `2026-06-20` — Rachas perdidas, reconcile y tests de integración
<kbd>Email</kbd> <kbd>Backend</kbd> <kbd>Testing</kbd>

El job diario no solo avisa: reconcilia rachas expiradas en Postgres aunque falle Brevo.

**Qué se implementó**
- `streak_lost` + `reconcileExpiredStreaksInDatabase`
- Dedupe `at_risk:YYYY-MM-DD` / `lost:YYYY-MM-DD`
- `tests/email.jobs.integration.test.ts`
- `npm run validate:email-flow` (circuito completo local)

**Impacto para el jugador**
- Mail empático al perder racha; servidor y juego alineados al loguear.
- Sin mails duplicados si el cron corre dos veces.

**Evidencia técnica**
- Commit `911d334`
- `scripts/validate-email-flow.ts`, `scripts/seed-streak-email-demo.ts`

---

### `2026-06-18` — Cron, retry y operación local/cloud
<kbd>Email</kbd> <kbd>CI</kbd> <kbd>Ops</kbd>

Jobs programados para rachas (19:00 ART) y reintentos (08:00 / 20:00 ART).

**Qué se implementó**
- `POST /internal/jobs/streak-emails` y `retry-failed-emails` con `X-Job-Secret`
- `.github/workflows/email-cron.yml`
- Scripts Windows: `register-email-tasks-windows.ps1`, `run-email-job.ps1`
- `EMAIL_ENABLED` master switch y auditoría `email_deliveries`

**Impacto para el equipo**
- Mismo contrato en dev, local y producción.
- Cero envíos accidentales en CI.

**Evidencia técnica**
- Commits `f13fb6f`, `7950cd1`
- `migrations/021_email_notifications.sql`, `022_email_deliveries_audit.sql`, `023_*`

---

### `2026-06-15` — Módulo email Brevo y consentimiento Godot
<kbd>Email</kbd> <kbd>Godot</kbd>

Primera integración transaccional: bienvenida, racha en riesgo, opt-in en registro y perfil.

**Qué se implementó**
- Módulo `BACKEND/src/modules/email/` (client, service, repository, templates)
- `accept_email_notifications` en registro; toggle en `auth.gd`
- Templates `welcome`, `streak_at_risk`, `streak_lost`
- Wiki inicial: `Entrega-4.md`, `Entrega-4-Mails.md`

**Impacto para el jugador**
- Puede elegir recordatorios de racha sin spam obligatorio.
- Bienvenida transaccional separada de marketing de hábito.

**Evidencia técnica**
- Commits `60a3694`, `84ea2dc`, `a7c9d0a`
- `BACKEND/docs/BREVO_SETUP.md`
- `juego/interface/auth.gd`, `juego/API/Login.tscn`
