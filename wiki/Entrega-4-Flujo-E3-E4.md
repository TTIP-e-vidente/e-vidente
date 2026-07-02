# Flujo E3 → E4 — Evolución de persistencia y notificaciones

Complemento de [Entrega-4](Entrega-4): qué reutilizamos de E3 y qué capa nueva agrega el canal de mail.

---

## En una línea

E3 dejó cuenta, racha en Postgres y el flag de notificaciones **sin envío real**. E4 activa Brevo + OTP + jobs, **sin reescribir** sync ni save local.

---

## Qué ya existía (E3)

| Componente | Uso en E4 |
|------------|-----------|
| `users.mail` | Destino OTP y recordatorios |
| `email_notifications_enabled` | Filtro SQL en jobs |
| `streaks` + `last_activity_day` | Candidatos `streak_at_risk` / `streak_lost` |
| Auth, perfil, sync | Registro con opt-in; racha al jugar online |
| Migraciones base | Extensión `021`–`028`, `037` |

---

## Qué se agregó (E4)

| Capa | Nuevo |
|------|-------|
| Postgres | `email_deliveries`, `email_verification_codes`, columnas en `users` |
| Supabase Edge | `verify-email-*`, `internal-job`, secrets Brevo |
| Operación | `pg_cron` → jobs 18:00 / 00:00 / 08:00 / 20:00 ART |
| Godot | UI OTP, toggle perfil; `api_mode` en `backend.local.json` |
| Contenido | 5 templates HTML en repo |

Diagrama: [Mer-Persistencia-E4](Mer-Persistencia-E4) · Base E3: [Mer-Persistencia-E3](Mer-Persistencia-E3)

---

## Flujo del jugador

**E3:** Registro → Login → Jugar → Racha en HUD (checkbox guardado, sin mail).

**E4:** Registro → OTP → Verificar → Welcome → Jugar → (si opt-in) mail de racha → panel in-game si pierde racha.

---

## Continuidad (sin regresiones)

| Tema | E4 |
|------|-----|
| Save local offline | Sin cambios |
| Sync y cola | Sin cambios |
| Dominio E1/E2 | Sin cambios |
| Recuperación contraseña | Fuera de alcance (E5 candidato) |

---

## Referencias

- [Entrega 3](Entrega-3) · [Sync Godot↔Postgres](Sync-Godot-Postgres)
- [Bitácora E3](Bitacora-Entrega-3) · [Bitácora E4](Bitacora-Entrega-4)
- `juego/niveles/progress/README.md` — evento in-game ↔ mail
