# Arquitectura — Entrega 1

Demo local en Godot. 

## Flujo confirmado

El jugador selecciona una restricción alimentaria desde el menú desplegado, una vez que selecciona alguno de ellos se abre un mapa con diferentes lecciones. Dentro de una partida existen varias modalidades de juego que van iterando entre arrastre, preguntas o vinculaciones, de manera aleatoria. A medida que uno va avanzando en el mapa va aumentando la dificultad según la partida, cada una está programada según su nivel de dificultad. Una vez finalizada una lección se registra la renovación de racha si ha mantenido una, y sino se vuelve a cargar una nueva racha. Junto con eso se suman puntos de experiencia al jugador y se desbloquean nuevas lecciones del mapa elegido.


## Componentes 

| Componente | Rol |
|---|---|
| `libro.gd` / `libro-vegan.gd` / `Libro-Vegan-GF.gd` | Selección de restricción por recorrido |
| `global.gd` | Estado global: `current_level`, flags de completado |
| `manager_level.gd` | Arma el `LevelResource` activo |
| `Level.gd` | Ejecuta la actividad y marca victoria |
| `level_resource.gd` / `level_item.gd` / `.tres` | Definición de contenido de la lección |
| `ItemLevel.gd` | Comportamiento visual del ítem arrastrable |
| `ensenanzas.gd` / `ensenanzaveganismo.gd` | Catálogo de enseñanzas por recorrido |
|`MapScene.gd`, `GameSceneRouter.gd`| Mapa donde se colocan las lecciones por restricción alimentaria |
|`pregunta.gd`| Modalidad de juego de preguntas y respuestas |
|`vincular_conceptos.gd`| Modalidad de juego de vincular conceptos | 
|`ArmadorDePartida.gd`| Ejecuta el armado de cada lección | 
|`barra de progreso.tscn`| Muestra el progreso visualmente para cada lección |
|contenidos por JSON| Documentos json que permiten hacer preguntas, vinculaciones y niveles de arrastre de manera rápida y fácil |


