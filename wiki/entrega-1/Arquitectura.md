# Arquitectura — Entrega 1

Demo local en Godot 4. No hay backend, autenticación, base de datos remota ni leaderboard en este alcance.

## Historia testigo

**Como jugador quiero elegir un nodo en el mapa y resolver la lección asignada para avanzar en mi recorrido educativo.**

Recorrido técnico de esa historia:

1. El jugador elige una restricción alimentaria → `libro.gd` / `libro-vegan.gd` abre el mapa correspondiente.
2. `MapScene.gd` construye el mapa y muestra los nodos disponibles.
3. Al elegir un nodo, `GameSceneRouter.gd` navega a la escena de lección.
4. `manager_level.gd` arma el `LevelResource` con el contenido del nodo (cargado desde JSON).
5. `ArmadorDePartida.gd` asigna la modalidad (Plato, Pregunta o Vincular) según la configuración del nodo.
6. `Level.gd` ejecuta la actividad y registra la victoria al completar.
7. `global.gd` actualiza el estado de la sesión y desbloquea el siguiente nodo.

## Componentes por responsabilidad

### UI / Vista

| Componente | Rol |
|---|---|
| `libro.gd` / `libro-vegan.gd` / `Libro-Vegan-GF.gd` | Selector de recorrido según restricción alimentaria |
| `MapScene.gd` | Mapa visual del recorrido con nodos disponibles |
| `barra de progreso.tscn` | Indicador de progreso durante la partida |

### Coordinación y navegación

| Componente | Rol |
|---|---|
| `global.gd` | Estado global de la sesión: nodo activo, flags de completado |
| `GameSceneRouter.gd` | Navegación entre escenas del juego |
| `manager_level.gd` | Arma el `LevelResource` activo según el nodo elegido |
| `ArmadorDePartida.gd` | Asigna modalidad y ejecuta el armado de cada lección |

### Gameplay

| Componente | Rol |
|---|---|
| `Level.gd` | Ejecuta la actividad activa y registra la victoria |
| `ItemLevel.gd` | Comportamiento visual del ítem arrastrable (modalidad Plato) |
| `pregunta.gd` | Modalidad Pregunta con dificultad progresiva |
| `vincular_conceptos.gd` | Modalidad Vincular conceptos |

### Datos y estado

| Componente | Rol |
|---|---|
| `level_resource.gd` / `level_item.gd` / `.tres` | Definición del contenido de cada lección |
| `ensenanzas.gd` / `ensenanzaveganismo.gd` | Catálogo de enseñanzas por recorrido |
| Contenido por JSON | Archivos externos para preguntas, vinculaciones y niveles de arrastre |

## Fuera de alcance en Entrega 1

Backend, autenticación, leaderboard, base de datos remota, panel de administración y telemetría no están incluidos. La demo corre completamente en local.


