# Arquitectura — Entrega 3

## Qué cambió respecto a Entrega 2

Entrega 2 cerró con un juego pulido que vivía 100 % en local. 
Entrega 3 suma una capa **opcional** de backend — Node, PostgreSQL, auth, sync y perfil — sin tocar la regla de oro: **el save local manda**.

---

## Piezas nuevas

### Backend (`BACKEND/`)

API REST con auth y jugador. PostgreSQL con Docker Compose. 
Migraciones versionadas para usuarios, perfil, progreso y partidas.

```
Godot (SaveManager local)
    ↓ HTTP (AuthApi / SyncApi)
Backend Node
    ↓
PostgreSQL
```

### Cliente Godot — capa API

En `juego/API/backend/` están los clientes HTTP, separados del gameplay. `interface/auth.gd` login y registro en Intro → Selector sin bloquear el modo offline.

### `ProgressSyncService`

El corazón del sync:

1. Siempre guarda local primero.
2. Encola resúmenes si no hay red o sesión.
3. Migra progreso local al iniciar sesión.
4. Reintenta en background.

### CI — smoke del vertical slice

`vertical_slice_smoke_test.gd` recorre Intro → Login → offline → Selector → mapa → partida → cierre. Es la red de seguridad en cada PR.

---

## Recorrido del jugador hoy

1. Intro → Jugar → Login (o continuar offline).
2. Selector de restricción → mapa celiaquía.
3. Partida armada desde JSON (`ArmadorDePartida`).
4. Al terminar: `SaveManager` local + sync opcional si hay JWT.
5. Vuelta al mapa — estado local al instante; remoto si el sync llegó.

---

## Dos lugares donde vive el progreso

Conviven **sin reemplazarse**:

| Store | Dónde | Rol |
|-------|-------|-----|
| Local | `user://save_data.json` (+ cola, sesión, avatares) | Fuente inmediata; juego offline |
| PostgreSQL | `BACKEND/migrations/` | Cuenta y backup remoto con sesión |

Esquema Postgres (post-migración `008`):

```
users → profiles → progress_restrictions → history_games → games
         └── streak_id → streaks
users.avatar_image_id → images
restriction_node_config (config, sin FK al jugador)
```

El **contenido del juego** — mapa, preguntas, ítems — sigue en `juego/contenido/*.json`. No va a tablas.

- Diagrama dual: [Mer-Persistencia-E3](Mer-Persistencia-E3)
- Mapeo: [MER](MER)
- Flujo sync: [Sync-Godot-Postgres](Sync-Godot-Postgres)
- Presentación E3: [Entrega-3-Presentacion](Entrega-3-Presentacion)

---

## Lo que dejamos para después

Leaderboard, refresh token, validador JSON en CI y deploy cloud.
