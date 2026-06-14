# Módulo de emails (Brevo)

Envío transaccional con auditoría en PostgreSQL. Los templates viven en `templates/` y se versionan en git.

## Estructura

```
email/
├── templates/
│   ├── layout.ts                 # HTML base, escape, footer
│   ├── welcome.template.ts
│   ├── streak-at-risk.template.ts
│   ├── streak-lost.template.ts
│   ├── types.ts
│   └── index.ts                  # registry + preview
├── email.service.ts              # orquestación
├── email.repository.ts           # DB + candidatos racha
├── email.client.ts               # API Brevo
├── email.config.ts
└── email.routes.ts               # endpoints dev
```

## Templates disponibles

| `template_key`   | Cuándo se envía                         | Consentimiento requerido |
|------------------|-----------------------------------------|--------------------------|
| `welcome`        | Registro exitoso con mail               | No (transaccional)       |
| `streak_at_risk` | Jugó ayer, hoy sin actividad            | Sí                       |
| `streak_lost`    | 2+ días sin actividad                   | Sí                       |

## Variables por template

- **welcome:** `name`, `mail`
- **streak_at_risk / streak_lost:** `name`, `mail`, `streakCount`

## Auditoría (`email_deliveries`)

Estados: `pending` → `sent` | `failed`

| Campo | Descripción |
|-------|-------------|
| `recipient_email` | Destino real del intento |
| `subject` | Asunto renderizado |
| `provider_message_id` | ID de Brevo |
| `error_message` | Error si falló |
| `attempt_count` | Reintentos sobre la misma fila |
| `dedupe_key` | Evita duplicados (`welcome`, `at_risk:YYYY-MM-DD`, `lost:YYYY-MM-DD`) |

Los `pending` viejos (> `EMAIL_PENDING_STALE_MINUTES`, default 15) pasan a `failed` automáticamente.

## Configuración (`.env`)

```env
EMAIL_ENABLED=false
BREVO_API_KEY=
BREVO_SENDER_EMAIL=noreply@tudominio.com
BREVO_SENDER_NAME=E-VIDENTE
EMAIL_CRON_SECRET=change_me
EMAIL_TIMEZONE=America/Argentina/Buenos_Aires
EMAIL_PENDING_STALE_MINUTES=15
```

## Endpoints dev (solo `NODE_ENV !== production`)

```http
GET /dev/email/templates
GET /dev/email/preview?template_key=welcome&name=Agus&mail=agus@test.com
GET /dev/email/preview?template_key=streak_at_risk&name=Agus&streak_count=7
GET /dev/email/deliveries?status=sent&limit=20
```

## Cron de rachas

```bash
npm run email:streaks
# o
POST /internal/jobs/streak-emails
Header: X-Job-Secret: <EMAIL_CRON_SECRET>
```

## Diseño visual

Los mails replican la UI del juego:

| Token | Valor | Uso en el juego |
|-------|-------|-----------------|
| Verde primario | `#42785e` | Botones, títulos, HUD |
| Chip salvia | `#c7d6a8` | Acentos suaves |
| Fondo crema | `#f4f7f2` | Fondo de escenas |
| Texto cuerpo | `#3e382a` | Labels y párrafos |
| Acento marrón | `#704533` | Mensajes de estado |
| Radio card | `28px` | Paneles de login/perfil |

Tipografía: **Rubik** (Google Fonts). En el juego el display usa Rubik Spray Paint; en email usamos Rubik 900 para el titular por compatibilidad con clientes de correo.

Editar estilos globales en `templates/layout.ts` (`GAME_EMAIL_THEME` + `wrapHtml`).

1. Abrí el archivo en `templates/*.template.ts`
2. Modificá `subject`, `textContent` y el HTML del body
3. Verificá con `GET /dev/email/preview?...`
4. Corré `npm run test:email` (unitarios de templates)

## Tests

```bash
npm run test:email
```
