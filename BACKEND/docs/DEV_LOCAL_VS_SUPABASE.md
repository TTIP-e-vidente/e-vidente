# Dev local vs Supabase (modo auto)

El juego decide solo contra qué backend correr, sin tocar configs:

```
Godot arranca (api_mode: "auto" en backend.local.json)
  └─ sonda http://localhost:3010/health (timeout 1.5 s)
       ├─ responde → usa el Express local
       │    └─ /health/db dice remote=false → datos en Postgres LOCAL
       │       (cuentas separadas con sufijo @local)
       │    └─ remote=true (dev:staging) → mismos datos que Supabase (sin sufijo)
       └─ no responde → Supabase Edge Functions directo
```

## Comandos

| Comando | Qué levanta | Datos |
|---|---|---|
| `npm run dev` | Docker Postgres (5433) + migraciones + Express :3010 | **Local** (espacio `@local`) |
| `npm run dev:staging` | Express :3010 conectado al pooler de Supabase | Supabase |
| (nada) | — | Supabase Edge directo |

`npm run sync:godot-config[:staging]` regenera `juego/config/backend.local.json`
en modo `auto` (guarda ambas URLs). `GODOT_API_MODE=local|cloud|supabase_edge`
pinea un modo fijo para debug.

## Separación de datos (no se mezclan entornos)

La **clave de cuenta** local es `username` + sufijo de entorno:

- Supabase (Edge o dev:staging): `agus` — igual que siempre, los saves
  existentes no cambian.
- Postgres local: `agus@local`.

Esa clave separa, por entorno: el vínculo del save (`linked_online_username`),
los snapshots por cuenta, la cola de sync offline (`owner`), el marcador de
avatar pendiente y la sesión persistida (`backend_session.json` guarda
`entorno`; una sesión de un entorno no se restaura en el otro — los tokens
además usan `JWT_SECRET` distintos).

El guardado offline/invitado no cambia: la demo funciona sin backend igual
que antes.

## Mails en cada modo

- **Supabase**: OTP y jobs de racha corren en Edge + pg_cron (ver
  `EMAILS_RUNBOOK.md`).
- **Local**: Express envía con el Brevo de `.env`; sin Brevo, el código OTP
  sale por consola (`dev_code`). Los jobs de racha se disparan a mano:
  `npm run email:streaks` / `npm run email:run-local`.

## Trampas conocidas

- El primer arranque de Godot con el stack local levantándose a medias puede
  resolver "Supabase": el botón **Reintentar** de la pantalla de login
  (`BackendConfig.recargar()`) vuelve a sondear.
- Si cambiás de entorno con el juego abierto, cerrá sesión primero: la
  resolución del modo ocurre al arrancar/reintentar, no en caliente.
