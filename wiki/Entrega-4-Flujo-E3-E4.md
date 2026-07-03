# Flujo E3 → E4 — Evolución de persistencia y notificaciones

## Qué se agregó (E4)

| Capa | Nuevo |
|------|-------|
| Postgres | `email_deliveries`, `email_verification_codes`, columnas en `users` |
| Supabase Edge | `verify-email-*`, `internal-job`, secrets Brevo |
| Operación | `pg_cron` → jobs 18:00 / 00:00 / 08:00 / 20:00 ART |
| Godot | UI OTP, toggle perfil; `api_mode` en `backend.local.json` |
| Contenido | 5 templates HTML en repo |

---

## Flujo del jugador

**E3:** Registro → Login → Jugar → Racha en HUD (checkbox guardado, sin mail).

**E4:** Registro → OTP → Verificar → Welcome → Jugar → (si opt-in) mail de racha → panel in-game si pierde racha.

