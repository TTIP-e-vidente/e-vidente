# Arquitectura — Entrega 3

## Cambios respecto a Entrega 2

Entrega 2 cerró el polish visual y las modalidades dentro de una demo 100 % local. Entrega 3 suma una capa opcional de backend (Node + PostgreSQL) y sincronización, mantiene el save local como fuente de verdad inmediata y refactoriza el mapa para escalar contenido sin posiciones hardcodeadas.

## Componentes nuevos

### Backend (`BACKEND/`)

API REST con módulos de autenticación y jugador. PostgreSQL vía Docker Compose. Migraciones versionadas para usuarios, perfil, progreso y partidas.

```
Godot (SaveManager local)
    ↓ HTTP (AuthApi / SyncApi)
Backend Node
    ↓
PostgreSQL
```

### Cliente Godot — capa API

`juego/API/backend/` con clientes HTTP desacoplados del gameplay. `interface/auth.gd` integra login/registro en el flujo Intro → Selector sin bloquear modo offline.

### `ProgressSyncService`

Servicio de sincronización que:

1. Guarda siempre local primero.
2. Encola resúmenes si no hay red o sesión.
3. Migra progreso local al iniciar sesión.
4. Reintenta en background sin acoplar escenas de partida a HTTP.

### Mapa — layout en curva

Pipeline de posicionamiento:

```
MapLayoutConfig → MapRouteRegistry → MapPathLayout → MapNodePositionResolver → MapBoard
```

Modo `anchors`: cada nodo `i` toma `curve.get_point_position(i)`. Diseñar el mapa = editar puntos en `Path2D`, no arrastrar nodos en el `.tscn`.

### CI — smoke vertical slice

`vertical_slice_smoke_test.gd` valida contratos mínimos de escenas y el recorrido Intro → Login → offline → Selector → mapa → partida → cierre.

## Flujo actualizado del jugador

1. Intro → opción Jugar → Login (o continuar offline).
2. Selector de restricción → mapa celiaquía (nodos posicionados por curva).
3. Partida armada desde JSON (`ArmadorDePartida` / nodo unificado UNQ-170).
4. Al terminar: `SaveManager` local + sync opcional si hay JWT activo.
5. Retorno al mapa con estado actualizado (local; remoto si sync OK).

## MER y persistencia (Entrega 3)

Conviven **dos stores** sin reemplazarse:

| Store | Ubicación | Rol |
|-------|-----------|-----|
| Local | `user://save_data.json` (+ cola, sesión, avatares) | Fuente inmediata; juego offline |
| PostgreSQL | `BACKEND/migrations/` | Cuenta y progreso remoto si hay sesión |

Esquema Postgres canónico (post-migración `008`):

```
users → profiles → progress_restrictions → history_games → games
         └── streak_id → streaks
users.avatar_image_id → images
restriction_node_config (config, sin FK al jugador)
```

El **contenido del juego** (mapa, preguntas, ítems) sigue en `juego/contenido/*.json` — no se modela en tablas.

- Diagrama dual: [mer-persistencia-e3.html](mer-persistencia-e3.html)
- Mapeo y tablas: [MER.md](MER.md)
- Flujo sync: [Sync-Godot-Postgres.md](Sync-Godot-Postgres.md)

## Fuera de esta capa arquitectónica

Leaderboard, refresh token, admin, validador JSON en CI y despliegue cloud — planificados pero no cerrados en Entrega 3.
