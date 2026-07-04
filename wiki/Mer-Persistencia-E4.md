# Persistencia E3 + E4 · vista interactiva

Extensión del modelo dual E3 con **mails transaccionales, OTP y operación Supabase**.

> **Idea central:** mails sin romper local-first — el juego sigue offline; el canal email vive en servidor.

---

## Abrir vista interactiva

| | |
|---|---|
| **Pantalla completa** | **[▶ Persistencia E4](https://raw.githack.com/TTIP-e-vidente/e-vidente/dev/wiki/mer-persistencia-e4.html?v=5)** |
| **Base sin email** | [Persistencia E3](Mer-Persistencia-E3) |

---

## Tips para verla mejor

La vista tiene dos pestañas: **Diagrama** (MER interactivo) e **Integración** (todo lo que se conectó + flujo cron explicado).

| Acción | Qué hace |
|--------|----------|
| Pestaña **Integración** | Qué se integró por capa + pipeline pg_cron → Brevo |
| Barra **①②③④** | Enfoca cada flujo en el diagrama |
| Botón **◎** | Centrar PostgreSQL |
| Tecla **`i`** | Ir a vista Integración · **`d`** diagrama |

> Naranja = nuevo en E4. La columna **Reglas E4** del canvas arranca oculta — activala en el panel si necesitás FK, filtros y migraciones.

---

## Cómo leerlo

```
PostgreSQL (centro)  →  users + email_*
Godot (izquierda)    →  cache UI, sin OTP ni outbox
Edge + Brevo (medio) →  único lugar que envía mails
```

| Color | Capa |
|-------|------|
| Azul | Godot local (`user://`) |
| Amarillo | Supabase Edge + `pg_cron` |
| Verde | PostgreSQL |
| Naranja | **Nuevo E4** |

---

## Flujos en 4 pasos

| | Qué pasa | Dónde mirar |
|---|----------|-------------|
| **① OTP** | Pide código → Edge hashea → `email_verification_codes` → Brevo | `EmailVerification.tscn` |
| **② Welcome** | Confirma OTP → `mail_verified_at` → outbox welcome | `verify-email-confirm` |
| **③ Racha** | `pg_cron` → job lee `streaks` → at_risk (18h) / last_chance (23h) / lost (00h) | Solo con opt-in |
| **④ Retry** | 08:00 / 20:00 reintenta `failed` con backoff | `email_deliveries` (037) |

Más detalle: [Entrega-4-Mails](Entrega-4-Mails) · [Flujo E3→E4](Entrega-4-Flujo-E3-E4)

---

## Tablas nuevas (E4)

### `email_deliveries` — outbox

| Columna | Rol |
|---------|-----|
| `template_key` · `dedupe_key` | Tipo + idempotencia (`UNIQUE`) |
| `status` | `pending` → `sent` \| `failed` \| `skipped` |
| `next_attempt_at` · `locked_at/by` | Backoff + claim cooperativo (037) |

### `email_verification_codes` — OTP

| Columna | Rol |
|---------|-----|
| `code_hash` | Nunca plaintext en DB |
| `target_mail` | Mail que se verifica |
| `failed_attempt_count` | Intentos fallidos (028) |

### `users` — columnas E4

| Columna | Rol |
|---------|-----|
| `mail_verified_at` | Gate welcome y recordatorios |
| `email_notifications_enabled` | Opt-in racha |
| `welcome_email_sent_at` | Marca post-envío |

Migraciones: `021` · `022` · `023` · `024` · `028` · `037`

---

## Equivalencia local ↔ remoto

| Godot | PostgreSQL |
|-------|------------|
| `backend_session` | `users.mail_verified_at` |
| `profile.email_notifications_enabled` | `users.email_notifications_enabled` |
| `save_data` v4 | Sin OTP ni outbox |
| streak local | `streaks` — jobs E4 leen para mails |

---

## Relacionado

| Doc | Link |
|-----|------|
| Esquema canónico | [MER](MER) |
| Persistencia E3 | [Mer-Persistencia-E3](Mer-Persistencia-E3) |
| Resumen E4 | [Entrega-4](Entrega-4) |
| Hub MER | [Mer-Hub](Mer-Hub) |
