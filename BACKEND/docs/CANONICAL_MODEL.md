# Modelo canonico de persistencia - E-VIDENTE

## Objetivo

Durante la PoC se genero una duplicacion de tablas al intentar alinear el esquema con el modelo visual de Excalidraw. Para evitar ampliar esa deuda, el backend adopta un conjunto canonico de tablas para todo codigo nuevo.

Las tablas duplicadas quedan en la base por compatibilidad historica de la PoC, pero no deben usarse para nuevas features.

## Tablas canonicas

| Responsabilidad | Tabla canonica | Tablas duplicadas/no canonicas | Decision |
|---|---|---|---|
| Usuario/Auth | `users` | - | Usar para registro, login y `/auth/me`. |
| Imagen/avatar | `user_images` | `images` | Usar `user_images`. |
| Perfil | `player_profiles` | `profiles` | Usar `player_profiles`. |
| Racha | `player_streaks` | `streaks` | Usar `player_streaks`. |
| Progreso | `player_progress` | `progress_restrictions` | Usar `player_progress`. |
| Partida/sesion | `game_sessions` | `history_games`, `games` | Usar `game_sessions`. |
| Nodos completados | `completed_nodes` | - | Usar `completed_nodes`. |
| Desbloqueos | `unlocked_content` | - | Usar `unlocked_content`. |

## Regla para codigo nuevo

Todo codigo nuevo debe usar solo tablas canonicas. Si una tabla canonica ya cubre una responsabilidad, no se debe crear ni usar una tabla paralela para la misma responsabilidad.

## Que NO hacer

- No crear tablas paralelas.
- No usar `profiles`, `streaks`, `progress_restrictions`, `history_games`, `games` o `images` para features nuevas.
- No borrar tablas duplicadas sin una migracion controlada futura.
- No conectar Godot todavia.

## Limpieza futura

Una migracion futura podra:

- verificar si las tablas duplicadas estan vacias;
- migrar datos si existieran;
- reemplazar referencias restantes;
- eliminar tablas duplicadas con autorizacion explicita.
