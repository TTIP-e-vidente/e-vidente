# Arquitectura — Entrega 2

## Cambios respecto a Entrega 1

En Entrega 2 el enfoque principal fue mejorar el diseño visual y la experiencia de juego, e implementar algunas modalidades pequeñas (interfaces y actividades nuevas) para que la experiencia sea más llamativa y atrapante. Estos cambios se integran al flujo existente sin romper la separación de responsabilidades.

## MER y persistencia

**Sin cambios en infraestructura ni esquema de datos.** La entrega fue 100 % presentación y gameplay (transiciones, estética, Completar Palabra, tests de carga JSON). El MER de dominio es el de Entrega 1 con la modalidad Completar Palabra agregada; la persistencia sigue siendo solo `save_data.json` local.

- Diagrama: [Mer-Dominio](Mer-Dominio) (nota E2 en leyenda)
- Índice: [MER.md](MER.md)

## Componentes  

### `GameSceneRouter.gd`

Centraliza toda la navegación entre escenas del juego. Antes de Entrega 2 las transiciones entre mapa, partida y resultados se hacían con cambios directos de escena. Ahora `GameSceneRouter` es el único punto de entrada para la navegación, aplica la transición animada correspondiente y garantiza que el contexto de sesión se preserve.

```
Mapa → [GameSceneRouter] → TransitionLayer → Partida
Partida → [GameSceneRouter] → TransitionLayer → Resultados
Resultados → [GameSceneRouter] → TransitionLayer → Mapa
```

### `TypewriterEffect.gd`

Vive en `sistemas/TypewriterEffect.gd` y extiende `RefCounted`. Recibe un `Callable` y un texto, y lo escribe carácter a carácter con un cursor `▌` intermedio. Cualquier escena puede instanciarlo con `TypewriterEffect.new()`.

La clase es compartida entre `pregunta.gd`, `completar_palabra.gd` y `DragObjectiveText`; así el delay entre caracteres y el cursor son idénticos en todas las pantallas sin duplicar lógica.

### `DragObjectiveText` (nodo de escena arrastre)

Componente visual dentro de `Level.tscn` que reemplaza a los nodos `Globo texto/Meal` y `Globo texto/Condition` eliminados en Entrega 2. Lee el objetivo de la actividad (`action`, `meal`, `connector`, `restriction`) desde el JSON del nodo y lo muestra usando `TypewriterEffect`.

### `completar_palabra.gd` / `completar_palabra.tscn`

Nueva modalidad educativa. Recibe un `Dictionary` con `prompt`, `correct_answers` y `choices` desde JSON. Los botones de opciones se generan dinámicamente a partir del contenido cargado; no están hardcodeados en la escena.

### Suite de tests GdUnit4 (`tests/preguntas/`)

Primera cobertura automatizada del proyecto. Valida el pipeline completo de carga de preguntas:
`JSON en disco → QuestionJsonLoader → ThemePreg → Preguntas → EvaluadorDeOpcionPregunta`.

## Flujo actualizado

El recorrido técnico del jugador para la historia testigo ahora incluye las transiciones:

1. El jugador elige una restricción alimentaria → `libro.gd` abre el mapa correspondiente.
2. `MapScene.gd` construye el mapa y muestra las partidas disponibles.
3. Al elegir una partida, **`GameSceneRouter.gd` ejecuta la transición** y navega a la escena del modo correspondiente.
4. `manager_level.gd` arma el `LevelResource` con el contenido del nodo desde JSON.
5. `ArmadorDePartida.gd` asigna la modalidad (Plato, Pregunta, Vincular o Completar Palabra).
6. La modalidad activa ejecuta la actividad; si es Arrastre, **`DragObjectiveText` muestra el objetivo con TypewriterEffect**.
7. `Level.gd` registra la victoria al completar.
8. **`GameSceneRouter` navega a resultados con transición**; si fue perfecto, se muestra la animación de estrellas.
9. `global.gd` actualiza el estado de la sesión y desbloquea el siguiente nodo.

### Coordinación y navegación

| Componente | Rol | Novedad |
|---|---|---|
| `GameSceneRouter.gd` | Navegación con transiciones entre escenas | 2 tipos de transiciones |
| `manager_level.gd` | Arma el `LevelResource` activo | Bug fix: sprites opcionales |

### Gameplay

| Componente | Rol | Novedad |
|---|---|---|
| `pregunta.gd` | Modalidad Pregunta | Nueva estética, TypewriterEffect |
| `vincular_conceptos.gd` | Modalidad Vincular conceptos | Nueva estética |
| `completar_palabra.gd` | Modalidad Completar Palabra | Nueva modalidad |
| `TypewriterEffect.gd` | Efecto de escritura progresiva | Efecto |

### Datos y estado

| Componente | Rol | Novedad |
|---|---|---|
| `QuestionJsonLoader.gd` | Carga preguntas desde JSON | Cubierto por tests |
| `CargadorCompletar.gd` | Carga desafíos de Completar Palabra | Normalización de formato |
| Contenido por JSON | Archivos externos para todas las modalidades | Mejoras de datos |

### Calidad

| Componente | Rol | Novedad |
|---|---|---|
| `tests/preguntas/carga_json_preguntas_test.gd` | Suite GdUnit4 para pipeline de preguntas | Test implementados |

