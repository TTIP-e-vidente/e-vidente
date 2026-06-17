# Decisiones — Entrega 4

## Por dónde arrancamos

Cerrar UNQ-64 y el circuito de mails sin acoplar Godot al proveedor, con consentimiento claro y auditoría en Postgres.

---

## Decisiones que tomamos

| Decisión | Por qué | Qué implica | ¿Queda algo? |
|----------|---------|-------------|--------------|
| Brevo vía API transaccional | SMTP simple, buen tier free, dashboard de entregas | `BREVO_API_KEY` solo en servidor | Dominio propio en producción |
| Templates en TypeScript versionados | Mismo repo que el backend; preview en dev | Cambios de copy = PR + `test:email` | Editor visual para no-devs |
| `EMAIL_ENABLED` master switch | Evitar envíos accidentales en CI/dev | Por defecto `false` en `.env.example` | Activar en deploy |
| Bienvenida sin consentimiento | Mail transaccional de alta de cuenta | No mezclar con marketing de racha | Copy honesto (sin “verificar cuenta”) |
| Rachas con opt-in | Respeto al jugador; menos spam | SQL filtra `email_notifications_enabled` | Texto opt-out en cada mail de racha |
| Dedupe en `email_deliveries` | Idempotencia ante cron duplicado o retry | `pending` bloquea segundo envío | Tests integración (`email.jobs.integration.test.ts`) |
| Cron 19:00 ART | Ventana razonable antes de fin del día local | `EMAIL_TIMEZONE=America/Argentina/Buenos_Aires` | Ajuste si hay jugadores en otras zonas |
| Godot no llama a Brevo | Separación de responsabilidades | Solo flags y registro HTTP | — |
| Feedback in-game + mail | Canales complementarios | UNQ-149 + UNQ-64 en paralelo | — |

---

## Cómo movimos las prioridades

1. Módulo completo en backend (implementado en E3 tardío / pre-E4).
2. Documentación wiki y copy editorial (Entrega 4).
3. Activación producción + dominio verificado.
4. ~~Tests de integración del job.~~ Hecho (`tests/email.jobs.integration.test.ts`).
5. Recuperación de contraseña por mail (entrega futura).
