# Arquitectura — Entrega 1

## Historia testigo

**Como jugador quiero elegir un nodo en el mapa y resolver la partida asignada para avanzar en mi recorrido educativo.**

Recorrido técnico de esa historia:

1. El jugador elige una restricción alimentaria → `libro.gd` / `libro-vegan.gd` abre el mapa correspondiente.
2. `MapScene.gd` construye el mapa y muestra los nodos disponibles.
3. Al elegir un nodo, `GameSceneRouter.gd` navega a la escena de partida.
4. `manager_level.gd` arma el `LevelResource` con el contenido del nodo (cargado desde JSON).
5. `ArmadorDePartida.gd` asigna la modalidad (Plato, Pregunta o Vincular) según la configuración del nodo.
6. `Level.gd` ejecuta la actividad y registra la victoria al completar.
7. `global.gd` actualiza el estado de la sesión y desbloquea el siguiente nodo.

## Flujo confirmado

El jugador selecciona una restricción alimentaria desde el menú desplegado, una vez que selecciona alguno de ellos se abre un mapa con diferentes lecciones/partidas. Dentro de una partida existen varias modalidades de juego que van iterando entre arrastre, preguntas o vinculaciones, de manera aleatoria. A medida que uno va avanzando en el mapa va aumentando la dificultad según la partida, cada una está programada según su nivel de dificultad. Una vez finalizada una partida se registra la renovación de racha si ha mantenido una, y sino se reiniciaría la racha desde cero. Junto con eso se suman puntos de experiencia al jugador y se desbloquean nuevas partidas del mapa elegido.


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
| `ArmadorDePartida.gd` | Asigna modalidad y ejecuta el armado de cada partida |

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
| `level_resource.gd` / `level_item.gd` / `.tres` | Definición del contenido de cada partida |
| `ensenanzas.gd` / `ensenanzaveganismo.gd` | Catálogo de enseñanzas por recorrido |
| Contenido por JSON | Archivos externos para preguntas, vinculaciones y niveles de arrastre |

## Fuera de alcance en Entrega 1

Backend, autenticación, leaderboard, base de datos remota, panel de administración y telemetría no están incluidos. La demo corre completamente en local.



