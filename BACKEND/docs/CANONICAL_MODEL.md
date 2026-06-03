# Modelo canónico de persistencia - E-VIDENTE

## Objetivo

Durante la PoC se generó una duplicación de tablas al intentar alinear el esquema con el modelo visual de Excalidraw. Para evitar ampliar esa deuda, el backend adopta un conjunto canónico de tablas para todo código nuevo.

Las tablas duplicadas quedan en la base por compatibilidad histórica de la PoC, pero no deben usarse para nuevas features.

## Tablas canónicas

| Responsabilidad | Tabla canónica | Tablas duplicadas/no canónicas | Decisión |
|---|---|---|---|
| Usuario/Auth | `users` | - | Usar para register, login y `/auth/me`. |
| Recuperación de contraseña | `password_reset_tokens` | - | Usar para tokens hasheados, expirables y de un solo uso. |
| Imagen/avatar | `user_images` | `images` | Usar `user_images`. |
| Perfil | `player_profiles` | `profiles` | Usar `player_profiles`. |
| Racha | `player_streaks` | `streaks` | Usar `player_streaks.profile_id` como relación 1 a 1 con `player_profiles`. |
| Progreso por restricción | `player_progress` | `progress_restrictions` | Usar `player_progress.profile_id + restriction_type`; UNIQUE(profile_id, restriction_type). |
| Partida/sesión | `game_sessions` | `history_games`, `games` | Usar `game_sessions.progress_id`. |
| Nodos completados | `completed_nodes` | - | Usar `completed_nodes.progress_id`; UNIQUE(progress_id, node_id). |
| Desbloqueos | `unlocked_content` | - | Usar `unlocked_content.progress_id`; UNIQUE(progress_id, content_id). |

## Equivalencia conceptual

| Excalidraw | PostgreSQL canónico | Decisión |
|---|---|---|
| USER | `users` | `username` es unique funcional; `id` UUID es PK física. |
| IMAGE | `user_images` | FK por `user_id`. |
| PROFILE | `player_profiles` | 1 a 1 con `users` vía `user_id UNIQUE`. |
| STREAK | `player_streaks` | 1 a 1 con `player_profiles` por `profile_id UNIQUE`. |
| PROGRESO_RESTRICTION | `player_progress` | Progreso por `profile_id + restriction_type`; CHECK restriction_type IN ('CELIAQUIA','VEG','VYG','KETO'). |
| HISTORY_GAME | `game_sessions` | Historial de partidas por `progress_id`. |
| GAME | `game_sessions` | Resultado de una sesión concreta (misma tabla). |

## Regla para código nuevo

Todo código nuevo debe usar solo tablas canónicas. Si una tabla canónica ya cubre una responsabilidad, no se debe crear ni usar una tabla paralela para la misma responsabilidad.

Reglas:

- Todo código nuevo usa solo tablas canónicas.
- No se agregan tablas paralelas.
- No se borran tablas duplicadas hasta una migración futura controlada.
- El DER conceptual no obliga a copiar nombres físicos.

Para jugador, el flujo relacional canónico es:

```txt
users -> player_profiles -> player_progress -> game_sessions
users -> player_profiles -> player_streaks
player_progress -> completed_nodes
player_progress -> unlocked_content
```

## Que NO hacer

- No crear tablas paralelas.
- No usar `profiles`, `streaks`, `progress_restrictions`, `history_games`, `games` o `images` para features nuevas.
- No borrar tablas duplicadas sin una migración controlada futura.
- No conectar Godot todavía.
- No almacenar tokens de recuperación en texto plano.
- No enviar emails reales hasta definir proveedor y contrato.

## Plan futuro

Una migración futura podrá:

- verificar si las tablas duplicadas están vacías;
- migrar datos si existieran;
- reemplazar referencias restantes;
- eliminar tablas duplicadas con autorización explícita.
