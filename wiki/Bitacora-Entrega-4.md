# Bitácora — Entrega 4

**emails transaccionales, verificación OTP y recordatorios de racha**.
---

### `2026-07-02` — MER persistencia E4 mejorado
<kbd>Docs</kbd> <kbd>MER</kbd>

`mer-persistencia-e4.html` reescrito al nivel de E3: toggles por capa, tablas completas según migraciones, `streaks`↔jobs, ciclo `email_deliveries`, equivalencia local↔remoto, strip de migraciones.

**Impacto**
- `Mer-Persistencia-E4.md` ampliado con tablas de columnas.

---
<kbd>Docs</kbd> <kbd>Jira</kbd> <kbd>Supabase</kbd>

stack Supabase Edge, Brevo y desafíos resueltos. 

**Qué se agregó**
- `Entrega-4-Flujo-Completo.md` — narrativa de punta a punta
- Trazabilidad ticket → US → implementación en `Entrega-4.md`
- Índices `Entregas.md` y `_Sidebar.md` actualizados con E4


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

---

### `2026-06-20` — Rachas perdidas, reconcile y tests de integración
<kbd>Email</kbd> <kbd>Backend</kbd> <kbd>Testing</kbd>

El job diario no solo avisa: reconcilia rachas expiradas en Postgres aunque falle Brevo.

**Qué se implementó**
- `streak_lost` + `reconcileExpiredStreaksInDatabase`
- Dedupe `at_risk:YYYY-MM-DD` / `lost:YYYY-MM-DD`
- `tests/email.jobs.integration.test.ts`

**Impacto para el jugador**
- Mail empático al perder racha; servidor y juego alineados al loguear.
- Sin mails duplicados si el cron corre dos veces.
---

### `2026-06-18` — Cron, retry y operación local/cloud
<kbd>Email</kbd> <kbd>CI</kbd> <kbd>Ops</kbd>

Jobs programados para rachas (19:00 ART) y reintentos (08:00 / 20:00 ART).

**Qué se implementó**
- `POST /internal/jobs/streak-emails` y `retry-failed-emails` con `X-Job-Secret`
- Crons: Supabase `pg_cron` → Edge `internal-job` (reemplaza workflow GitHub histórico)
- Scripts Windows: `register-email-tasks-windows.ps1`, `run-email-job.ps1`
- `EMAIL_ENABLED` master switch y auditoría `email_deliveries`

**Impacto para el equipo**
- Mismo contrato en dev, local y producción.
- Cero envíos accidentales en CI.


