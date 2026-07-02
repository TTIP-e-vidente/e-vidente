# Persistencia E3 + E4 · vista interactiva

Extensión del modelo dual E3 con **mails transaccionales, OTP y operación Supabase**. El diagrama centra el esquema relacional email sobre `users` y `streaks`, con capas Godot local y Edge a los lados.

---

## Abrir

**[▶ Persistencia E4 — pantalla completa](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e4.html?v=2)**

Base E3 (sin email): [Persistencia E3](Mer-Persistencia-E3)

---

## Qué muestra el diagrama

| Zona | Contenido |
|------|-----------|
| **Godot local** | `backend.local.json`, `save_data.json` v4, `backend_session.json`, `EmailVerification.tscn` |
| **Supabase Edge** | `verify-email-*`, `internal-job`, `pg_cron`, Brevo (5 templates) |
| **PostgreSQL** | `users` (E3 + columnas E4), `streaks`, `profiles`, `email_deliveries`, `email_verification_codes` |
| **Reglas E4** | FK, filtros de jobs, qué no va al save local, dual `api_mode`, migraciones |

**Panel lateral:** toggles por capa, equivalencia local ↔ remoto, horarios cron ART.

---

## Tablas nuevas (E4)

### `email_deliveries` — outbox + auditoría

| Columna | Rol |
|---------|-----|
| `template_key` · `dedupe_key` | Tipo de mail + idempotencia (`UNIQUE` por usuario) |
| `status` | `pending` → `sent` \| `failed` \| `skipped` |
| `provider_message_id` | Trazabilidad Brevo |
| `next_attempt_at` · `locked_at/by` | Backoff y claim cooperativo (037) |

### `email_verification_codes` — OTP

| Columna | Rol |
|---------|-----|
| `code_hash` | Nunca plaintext en DB |
| `target_mail` | Mail que se verifica |
| `failed_attempt_count` | Intentos fallidos (028) |

### `users` — columnas E4

| Columna | Rol |
|---------|-----|
| `mail_verified_at` | Gate para welcome y recordatorios |
| `email_notifications_enabled` | Opt-in recordatorios de racha |
| `welcome_email_sent_at` | Marca post-envío welcome |

Migraciones: `021` · `022` · `023` · `024` · `028` · `037`

---

## Equivalencia local ↔ remoto

| Godot local | PostgreSQL |
|-------------|------------|
| `backend_session` cache | `users.mail_verified_at` |
| `profile.email_notifications_enabled` | `users.email_notifications_enabled` |
| `save_data` v4 | Sin OTP ni outbox |
| streak en save | `streaks` (E3) — jobs E4 leen para at_risk/lost |

---

## Relacionado

| Doc | Link |
|-----|------|
| Esquema canónico | [MER](MER) |
| Persistencia base E3 | [Mer-Persistencia-E3](Mer-Persistencia-E3) |
| Resumen entrega | [Entrega-4](Entrega-4) |
| Flujo E3→E4 | [Entrega-4-Flujo-E3-E4](Entrega-4-Flujo-E3-E4) |
| Hub MER | [Mer-Hub](Mer-Hub) |
