# Entrega 4 — E-VIDENTE

> Stack actual: [SUPABASE_QUICKSTART](../BACKEND/docs/SUPABASE_QUICKSTART.md) · Setup Godot: `npm run sync:godot-config:staging`

## Resumen ejecutivo

En Entrega 3 el jugador tenía cuenta, racha en PostgreSQL y un checkbox de notificaciones, pero **nunca llegaba un correo**. Entrega 4 cierra ese circuito: mails transaccionales con Brevo, verificación OTP, recordatorios de racha con consentimiento y auditoría en base de datos. El stack productivo corre en **Supabase Edge Functions + Postgres + pg_cron**; Godot solo habla HTTP con el backend y **nunca ve la API key de Brevo**. El save local, el sync de progreso y el dominio del juego (E1/E2) siguen igual — E4 es una capa transversal de comunicación sobre la infraestructura E3.

## Qué se agregó o modificó

- **Proveedor de mail** — integración Brevo (API transaccional), templates HTML versionados en código, interruptor `EMAIL_ENABLED` para dev/CI.
- **Verificación OTP** — código de 6 dígitos al registrarse o cambiar mail; UI en Godot (`EmailVerification`); `mail_verified_at` en Postgres antes de bienvenida o recordatorios.
- **Cinco correos** — `email_verification`, `welcome` (post-OTP), `streak_at_risk`, `streak_lost`, `mail_changed` (aviso al mail anterior).
- **Consentimiento** — opt-in en registro y toggle en perfil (`email_notifications_enabled`); rachas por mail solo con flag activo y mail verificado.
- **Jobs programados** — `pg_cron` en Supabase dispara Edge `internal-job`: racha en riesgo (18:00 ART), racha perdida (00:00 ART), reintentos (08:00 / 20:00 ART).
- **Auditoría** — tabla `email_deliveries` con dedupe, estados, retry y `provider_message_id` de Brevo.
- **Supabase Edge** — `verify-email-request/confirm`, módulo email compartido, secrets Brevo en Edge; reemplaza Express en staging (`api_mode=supabase_edge`).
- **Godot dual local/cloud** — `backend.local.json` con `api_mode` (`supabase_edge` / `auto` / `local`); cache de sesión para flags de mail; `save_data.json` v4 sin cambio de esquema.
- **MER y persistencia** — 2 tablas nuevas (`email_deliveries`, `email_verification_codes`) + columnas en `users`; diagrama en [Mer-Persistencia-E4](Mer-Persistencia-E4).
- **In-game** — badge de racha en riesgo en HUD, panel `StreakLossMessagePanel` al perder racha (complemento al mail).
- **Tests y operación** — smokes Edge, `verify:integration:full`, runbook de mails, seed demo de rachas.

## Desafíos técnicos

- Evitar mails duplicados si el cron o el retry corre dos veces (`dedupe_key` + estado `pending` en `email_deliveries`).
- Separar transaccional (OTP, bienvenida, seguridad) de recordatorios de hábito (requieren opt-in explícito).
- No bloquear registro ni gameplay si Brevo falla — outbox async y reconcile de racha independiente del envío.
- Impedir mails a direcciones typo o falsas — OTP obligatorio antes de recordatorios.
- Mantener Godot desacoplado de Brevo y de SQL de mail — solo REST a Edge; auditoría centralizada en servidor.
- Convivir Express (tests locales) y Supabase Edge (staging/juego online) sin duplicar lógica de negocio.
- Zona horaria única ART para candidatos de racha (`EMAIL_TIMEZONE`).

## Continuidad con Entrega 3

| De E3 (reutilizado) | Qué agrega E4 |
|---------------------|---------------|
| `users`, `streaks`, sync, auth JWT | Columnas mail + tablas `email_*` |
| `email_notifications_enabled` (flag sin efecto) | Jobs que lo respetan + UI funcional |
| Rachas en servidor al jugar online | Candidatos SQL + mails `streak_*` |
| Save local + cola offline | Sin cambios — gameplay offline intacto |
| Express / Docker (dev) | Edge + pg_cron en Supabase (staging) |

Detalle técnico: [Flujo E3→E4](Entrega-4-Flujo-E3-E4) · [Sync Godot↔Postgres](Sync-Godot-Postgres)

## Trazabilidad ticket → entregable

| Ticket | Resumen | Bloque |
|--------|---------|--------|
| [UNQ-64](https://tip-unq.atlassian.net/browse/UNQ-64) | Notificaciones email racha | Jobs, dedupe, `streak_at_risk` / `streak_lost` |
| [UNQ-177](https://tip-unq.atlassian.net/browse/UNQ-177) | Mail de bienvenida | `welcome` post-OTP |
| [UNQ-190](https://tip-unq.atlassian.net/browse/UNQ-190) | Configurar Brevo | Proveedor + secrets Edge |
| [UNQ-149](https://tip-unq.atlassian.net/browse/UNQ-149) | Mensaje pérdida racha in-game | `StreakLossMessagePanel` |
| [UNQ-90](https://tip-unq.atlassian.net/browse/UNQ-90) | Registro de usuario | OTP al alta, opt-in |
| [UNQ-27](https://tip-unq.atlassian.net/browse/UNQ-27) | Perfil de usuario | Toggle notificaciones, `mail_changed` |
| [UNQ-83](https://tip-unq.atlassian.net/browse/UNQ-83) | Indicador visual racha | Badge HUD (complemento) |

Fuera de alcance Jira: [UNQ-69](https://tip-unq.atlassian.net/browse/UNQ-69) recuperación contraseña → candidato E5.

## Alcance de Entrega 4

| Bloque | Resultado | Estado |
|--------|-----------|--------|
| Módulo email (Brevo) | Cliente, service, 5 templates, tests | Listo |
| Verificación OTP | Edge + UI Godot + límites de intento | Listo |
| Mail de bienvenida | Post-verificación, outbox async | Listo |
| Aviso cambio de mail | Notificación al mail anterior | Listo |
| Racha en riesgo | Cron 18:00 ART + SQL candidatos | Listo |
| Racha perdida | Cron 00:00 ART + reconcile en DB | Listo |
| Reintento fallidos | Jobs 08:00 / 20:00 ART | Listo |
| Consentimiento UI | Registro + perfil | Listo |
| Auditoría Postgres | `email_deliveries` + observabilidad | Listo |
| Supabase Edge + pg_cron | Staging integrado, smokes | Listo |
| MER E3+E4 | Diagrama persistencia email | Listo |
| Tests integración / E2E | Jobs, dedupe, `verify:integration:full` | Listo |
| Activación producción | Dominio propio SPF/DKIM | Pendiente |

### Fuera de alcance

Recuperación de contraseña por mail, newsletters, push nativas, editor visual de templates en Brevo, zonas horarias por jugador.

## Cómo probar (rápido)

Desde `BACKEND/`:

```bash
npm run verify:integration:full    # integral staging (~3 min)
npm run smoke:verify-email-edge    # OTP end-to-end
npm run platform:doctor:staging    # diagnóstico "no llegan mails"
```

En Godot: F5 → registro → verificar OTP → jugar con cuenta online. Más opciones: [Guía rápida E4](Entrega-4-Guia-Rapida) · [Evidencia](Entrega-4-Evidencia).

## Documentación

- [User Stories](Entrega-4-User-Stories)
- [Arquitectura](Entrega-4-Arquitectura)
- [Decisiones](Entrega-4-Decisiones)
- [Evidencia](Entrega-4-Evidencia)
- [Mails (copy)](Entrega-4-Mails)
- [Flujo E3→E4](Entrega-4-Flujo-E3-E4)
- [MER persistencia E4](Mer-Persistencia-E4) · [Hub MER](Mer-Hub)
- [Bitácora E4](Bitacora-Entrega-4)

**Profundización** (Jira, secuencias, runbook): [Flujo completo E4](Entrega-4-Flujo-Completo) · [Guía rápida 5 min](Entrega-4-Guia-Rapida)

**Entrega anterior:** [Entrega 3](Entrega-3)
