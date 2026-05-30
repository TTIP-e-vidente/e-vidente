# Arquitectura — Entrega 2

## Cambios respecto a Entrega 1

En Entrega 2 el enfoque principal fue mejorar el diseño visual y la experiencia de juego, e implementar algunas modalidades pequeñas (interfaces y actividades nuevas) para que la experiencia sea más llamativa y atrapante. Estos cambios se integran al flujo existente sin romper la separación de responsabilidades.

## Componentes nuevos 

### `GameSceneRouter.gd`

Centraliza toda la navegación entre escenas del juego. Antes de Entrega 2 las transiciones entre mapa, partida y resultados se hacían con cambios directos de escena. Ahora `GameSceneRouter` es el único punto de entrada para la navegación, aplica la transición animada correspondiente y garantiza que el contexto de sesión se preserve.

```
Mapa → [GameSceneRouter] → TransitionLayer → Partida
Partida → [GameSceneRouter] → TransitionLayer → Resultados
Resultados → [GameSceneRouter] → TransitionLayer → Mapa
```

### `TypewriterEffect.gd`

Vive en `sistemas/TypewriterEffect.gd` y extiende `RefCounted` (sin nodo propio). Recibe un `Callable` y un texto, y lo escribe carácter a carácter con un cursor `▌` intermedio. Cualquier escena puede instanciarlo con `TypewriterEffect.new()` sin engancharse a la jerarquía de nodos.

La clase es compartida entre `pregunta.gd`, `completar_palabra.gd` y `DragObjectiveText`; así el delay entre caracteres y el cursor son idénticos en todas las pantallas sin duplicar lógica.

#### Cómo funciona

```
iniciar(nodo, callable, texto)
       │
  _id_llamada_vigente++      ← cancela cualquier animación anterior
  initial_delay (0.15 s)
       │
  bucle carácter a carácter
    ├─ id cambió → return     ← nueva llamada nos reemplazó
    ├─ salto solicitado → texto completo, break
    ├─ callable(fragmento + CURSOR)
    └─ await character_delay (0.035 s)
       │
  callable(texto_completo)   ← limpia cursor
  after_finish_delay (0.10 s)
```

Llamar `iniciar()` de nuevo cancela el loop anterior automáticamente, por lo que nunca hay caracteres mezclados entre preguntas. En `pregunta.gd`:

```gdscript
var _typewriter: TypewriterEffect = TypewriterEffect.new()

# en _cargar_pregunta_actual():
_typewriter.iniciar(self, func(t: String): pregunta_label.text = t, pregunta_actual.info_pregunta)
# en _input():
_typewriter.solicitar_salto()
```

#### API

| Símbolo | Tipo | Default | Descripción |
|---|---|---|---|
| `character_delay` | `float` | `0.035` | Segundos entre caracteres. |
| `initial_delay` | `float` | `0.15` | Pausa antes del primer carácter. |
| `after_finish_delay` | `float` | `0.10` | Pausa al terminar. |
| `allow_skip` | `bool` | `true` | Toque/clic muestra el texto completo de inmediato. |
| `iniciar(nodo, callable, texto)` | `func` | — | Arranca la animación. Awaitable. |
| `solicitar_salto()` | `func` | — | Salta la animación en curso. |
| `esta_escribiendo()` | `func → bool` | — | `true` si hay animación activa. |

### `DragObjectiveText` (nodo de escena)

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
7. `Level.gd` o la modalidad registra la victoria al completar.
8. **`GameSceneRouter` navega a resultados con transición**; si fue perfecto, se muestra la animación de estrellas.
9. `global.gd` actualiza el estado de la sesión y desbloquea el siguiente nodo.

## Componentes por responsabilidad (actualizado)

### UI / Vista

| Componente | Rol | Novedad |
|---|---|---|
| `libro.gd` / `libro-vegan.gd` / `Libro-Vegan-GF.gd` | Selector de recorrido | Sin cambios |
| `MapScene.gd` | Mapa visual con nodos | Título de nivel actualizado |
| `DragObjectiveText` | Mensaje de objetivo en Arrastre | **Nuevo en Entrega 2** |
| `completar_palabra.tscn` | Interfaz de la modalidad Completar Palabra | **Nueva gráfica en Entrega 2** |

### Coordinación y navegación

| Componente | Rol | Novedad |
|---|---|---|
| `GameSceneRouter.gd` | Navegación con transiciones entre escenas | **Ampliado en Entrega 2** |
| `global.gd` | Estado global de la sesión | Sin cambios |
| `manager_level.gd` | Arma el `LevelResource` activo | Bug fix: sprites opcionales |
| `ArmadorDePartida.gd` | Asigna modalidad y ejecuta el armado | Sin cambios |

### Gameplay

| Componente | Rol | Novedad |
|---|---|---|
| `Level.gd` | Ejecuta la actividad activa | Sin cambios |
| `pregunta.gd` | Modalidad Pregunta | Nueva estética, TypewriterEffect |
| `vincular_conceptos.gd` | Modalidad Vincular conceptos | Nueva estética |
| `completar_palabra.gd` | Modalidad Completar Palabra | **Normalizada en Entrega 2** |
| `TypewriterEffect.gd` | Efecto de escritura progresiva | **Nuevo en Entrega 2** |

### Datos y estado

| Componente | Rol | Novedad |
|---|---|---|
| `QuestionJsonLoader.gd` | Carga preguntas desde JSON | Cubierto por tests |
| `CargadorCompletar.gd` | Carga desafíos de Completar Palabra | Normalización de formato |
| Contenido por JSON | Archivos externos para todas las modalidades | Sin cambios estructurales |

### Calidad

| Componente | Rol | Novedad |
|---|---|---|
| `tests/preguntas/carga_json_preguntas_test.gd` | Suite GdUnit4 para pipeline de preguntas | **Nueva en Entrega 2** |

## Fuera de alcance en Entrega 2

Backend, autenticación, leaderboard, base de datos remota, panel de administración, telemetría y restricciones alimentarias adicionales no están incluidos. La demo sigue corriendo completamente en local.
