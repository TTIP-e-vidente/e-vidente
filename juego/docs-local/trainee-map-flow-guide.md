# Guía trainee: flujo del mapa al juego

Para entender este flujo no necesitás leer todos los archivos.
Leé esta guía primero. Si necesitás modificar algo, la sección "qué archivo tocar si quiero…" te dice exactamente a dónde ir.

---

## El flujo en lenguaje simple

1. El juego carga el mapa desde un archivo JSON.
2. El mapa muestra un círculo por cada nodo. Su posición viene del JSON.
3. El jugador toca un nodo.
4. El juego pregunta: ¿este nodo está desbloqueado?
   - Si está bloqueado → muestra un mensaje y no hace nada más.
   - Si está desbloqueado → arma una lista de actividades y abre la primera.
5. El jugador juega cada actividad (quiz, arrastre, etc.).
6. Al terminar el último mini-juego, el juego vuelve al mapa.

---

## Diagrama: desde el JSON hasta la escena jugable

```
celiaquia_mapa.json
  │  (cargado por CargadorDeMapa.gd)
  ▼
MapNodeData  ←  objeto en memoria con: node_key, modo, posición, juegos
  │  (renderizado por MapBoard.gd)
  ▼
MapNode.tscn  ←  un círculo en la pantalla por cada nodo
  │  (clic del jugador)
  ▼
MapScene._on_node_selected(node_data)
  │  (delega en)
  ▼
MapFlow.seleccionar_nodo()
  ├── ¿bloqueado? → feedback visual → termina
  └── ¿libre? → AbridorDeNodoJugable.abrir_nodo(tree, node_data)
  │
  ▼
NodePlaySession.build_from(node_data)
  │  (objeto que describe QUÉ se va a jugar)
  ▼
NodoRuntime.iniciar_desde_sesion(tree, session)
  │  (arma el plan y configura el estado global)
  ▼
ArmadorDePartida.construir_plan_de_partida(node_data)
  │  (devuelve lista ordenada de actividades)
  ▼
ContinuidadDePartidaDeNodo.abrir_juego_actual(tree)
  │  (determina qué escena abrir según el modo)
  ▼
GameSceneRouter.ir_a_modo_jugable(tree, mode)
  │
  ▼
pregunta.tscn / Level.tscn / VincularConceptos.tscn / completar_palabra.tscn
```

---

## Qué archivo tocar si quiero…

### Mover un nodo en el mapa
**Archivo**: `contenido/mapa/celiaquia_mapa.json`

Cada nodo tiene:
```json
"map_position": { "x": 804, "y": 414 },
"map_scale": 1.8
```
Cambiá esos valores. El mapa los lee automáticamente al iniciar.

No toques `MapBoard.tscn` — el diseño del mapa se construye desde datos.

---

### Cambiar el título de un nodo
**Archivo**: `contenido/mapa/celiaquia_mapa.json`

Cada nodo tiene:
```json
"title": "Desayuno básico sin TACC"
```
Cambiá ese texto. `MapNodeData.title` lo levanta del JSON.

---

### Cambiar el contenido (preguntas, alimentos, palabras)
**Archivos según modalidad**:

| Modo | Carpeta de contenido |
|---|---|
| `quiz_choice` | `contenido/catalogos/` — JSONs con preguntas |
| `drag_drop` | `contenido/ejemplos/` — JSONs con alimentos |
| `vinculacion_conceptos` | `contenido/catalogos/` — JSONs de conceptos |
| `completar_palabra` | `contenido/catalogos/` — JSONs de palabras |

El nodo del mapa apunta a su contenido por `node_key`. El sistema lo resuelve solo.

---

### Cambiar el diseño visual de los nodos del mapa
**Archivo**: `mapas/MapNode.tscn` + `mapas/MapNode.gd`

`MapNode.tscn` es la escena de cada círculo. Si querés:
- Cambiar el ícono → modificá `Icon` Sprite2D en `MapNode.tscn` o asigná una textura distinta.
- Cambiar el shader de hover → modificá `ShaderMaterial_hover` en `MapNode.tscn`.
- Cambiar la lógica de estados (disponible/bloqueado/completado) → editá `MapNode.gd`.

Un solo cambio en `MapNode.tscn` afecta todos los nodos del mapa.

---

### Agregar un nodo al mapa
**Archivo**: `contenido/mapa/celiaquia_mapa.json`

Agregá un nuevo objeto al diccionario `nodes`:
```json
"31": {
  "node_key": "celiaquia_31_nuevo_nodo",
  "title": "Mi nuevo nodo",
  "mode": "quiz_choice",
  "map_position": { "x": 600, "y": 2900 },
  "map_scale": 1.5,
  "games": [...]
}
```
El mapa lo instancia automáticamente al cargar. No toques `MapBoard.tscn`.

---

### Agregar una nueva modalidad de juego
Requiere 3 pasos:

1. **Crear la escena jugable** en la carpeta correspondiente (ej. `mi_modalidad/mi_modalidad.tscn`).
2. **Registrar el modo** en `sistemas/ModalidadRouter.gd`:
   ```gdscript
   const MODE_MI_MODALIDAD := "mi_modalidad"
   # En resolver_scene_path():
   MODE_MI_MODALIDAD: return "res://mi_modalidad/mi_modalidad.tscn"
   ```
3. **Registrar la ruta** en `niveles/GameSceneRouter.gd`:
   ```gdscript
   const MODE_TO_SCENE_PATH := {
       ...
       "mi_modalidad": "res://mi_modalidad/mi_modalidad.tscn",
   }
   ```
4. **Usar el modo** en el JSON del nodo:
   ```json
   "mode": "mi_modalidad"
   ```

---

### Modificar el feedback de nodo bloqueado
**Archivo**: `mapas/MapScene.gd`

Buscá esta función:
```gdscript
func _on_nodo_bloqueado(_node_key: String) -> void:
    _show_open_error("Este nodo todavía está bloqueado.")
```
Cambiá el texto o reemplazá `_show_open_error` por una UI más elaborada (popup, animación, etc.).

---

## Tabla de archivos del flujo

| Archivo | Responsabilidad | Nivel de lectura para trainee |
|---|---|---|
| `contenido/mapa/celiaquia_mapa.json` | Fuente de verdad del mapa: posiciones, modos, juegos, títulos | Fácil — es solo JSON |
| `mapas/MapScene.gd` | Coordinador visual. Carga el mapa, conecta señales, maneja errores | Medio — hay lógica de scroll y estados |
| `flow/map/map_flow.gd` | Decide si el nodo está desbloqueado. Emite señales. | Fácil — solo 40 líneas |
| `mapas/MapBoard.gd` | Instancia `MapNode.tscn` por cada nodo. Lee posición del JSON. | Fácil — el loop de instanciación es claro |
| `mapas/MapNode.gd` | Nodo visual individual: estados, colores, badge, clic. | Medio — tiene lógica visual de estados |
| `mapas/logica/AbridorDeNodoJugable.gd` | Punto de entrada al juego. Construye la sesión y llama a NodoRuntime. | Fácil — solo 35 líneas |
| `flow/session/NodePlaySession.gd` | Objeto de datos: describe qué se va a jugar. | Fácil — solo propiedades y un factory |
| `sistemas/NodoRuntime.gd` | Motor de inicio: arma el plan, configura Global, abre la primera escena. | Avanzado — interactúa con Global (autoload) |
| `mapas/logica/ArmadorDePartida.gd` | Construye la lista de actividades del nodo. Maneja randomización. | Avanzado — lógica de selección de juegos |

---

## Estado actual del sistema — cerrado para demo

Los siguientes archivos están **congelados**. No los toques salvo bug real verificado:

| Archivo | Por qué está congelado |
|---|---|
| `sistemas/NodoRuntime.gd` | Motor central de inicio/avance de partida. Un cambio rompe el flujo completo. |
| `mapas/logica/ArmadorDePartida.gd` | Lógica compleja de construcción de planes. Está probada con todos los nodos del mapa. |
| `mapas/logica/ContinuidadDePartidaDeNodo.gd` | Controla el avance entre actividades y el retorno al mapa. |
| `sistemas/ModalidadRouter.gd` | Resuelve qué escena abrir según el modo. No agregar ni cambiar rutas. |
| `niveles/GameSceneRouter.gd` | Navegación central de escenas. No modificar paths. |
| `flow/session/NodePlaySession.gd` | Contrato entre el mapa y el motor. No agregar campos. |
| `contenido/mapa/celiaquia_mapa.json` | Fuente de verdad. No cambiar estructura de claves. |

Archivos **modificables para cambios de mapa visual/datos**:

| Archivo | Qué podés cambiar con seguridad |
|---|---|
| `mapas/MapNode.gd` | Colores, animaciones, íconos, feedback visual de estados |
| `mapas/MapNode.tscn` | Agregar nodos visuales (badge, label, icon) |
| `mapas/MapBoard.gd` | Lógica de posicionamiento y render de nodos |
| `mapas/MapScene.gd` | Feedback de errores, scroll, popup de completado |
| `contenido/mapa/celiaquia_mapa.json` | Posiciones, títulos, escala de nodos |

---

## Checklist: agregar un nodo nuevo al mapa

1. Abrí `contenido/mapa/celiaquia_mapa.json`.
2. Agregá una nueva entrada al diccionario `nodes` con un `node_key` único (ej. `"celiaquia_31_nuevo"`).
3. Completá los campos requeridos: `title`, `mode`, `map_position`, `map_scale`, `games`.
4. Si querés que sea el primer nodo desbloqueado, agregá `"default_unlocked": true`.
5. Reiniciá el mapa en el editor. El nodo aparece automáticamente posicionado.

No toques `MapBoard.tscn` ni `MapBoard.gd` — el nodo se instancia desde datos.

---

## Checklist: cambiar el visual de los nodos

### Cambiar colores de estado
**Archivo**: `mapas/MapNode.gd`

Buscá las constantes al inicio del archivo:
```gdscript
const COLOR_AVAILABLE := Color(1.0, 0.96, 0.84, 1.0)  # disponible
const COLOR_COMPLETED := Color("#42785e")               # completado (icon)
const COLOR_LOCKED    := Color(0.55, 0.55, 0.65, 0.60) # bloqueado
```
Cambiá los valores. `COLOR_LOCKED` es el modulate del nodo entero. `COLOR_COMPLETED` es el tinte del ícono.

### Cambiar el ícono según modalidad
**Archivo**: `mapas/MapNode.gd`

Buscá las constantes de íconos:
```gdscript
const ICON_QUIZ_CHOICE := preload("res://assets-sistema/mapa/desafio-mapa-1.png")
const ICON_DRAG_DROP   := preload("res://assets-sistema/mapa/desafio-mapa-2.png")
const ICON_VINCULACION := preload("res://assets-sistema/mapa/desafio-mapa-3.png")
const ICON_COMPLETAR   := preload("res://assets-sistema/mapa/desafio-mapa-4.png")
const ICON_DEFAULT     := preload("res://assets-sistema/mapa/desafio-mapa-8.png")
```
Reemplazá el path por otro PNG ya importado en `assets-sistema/mapa/`.

### Cambiar la animación del nodo disponible
**Archivo**: `mapas/MapNode.gd`, función `_animar_disponible()`

El nodo disponible pulsa suavemente en loop. Cambiá la velocidad (`0.75`) o escala (`1.07`) según necesites.

### Cambiar el texto del feedback de nodo bloqueado
**Archivo**: `mapas/MapScene.gd`, función `_on_nodo_bloqueado()`

```gdscript
func _on_nodo_bloqueado(_node_key: String) -> void:
    _mostrar_toast_bloqueado("Este nodo todavía está bloqueado.")
```
Cambiá el string. El toast dura ~2 segundos y no bloquea input.
| `mapas/logica/ContinuidadDePartidaDeNodo.gd` | Avanza entre actividades y finaliza la partida. | Avanzado — interactúa con Global y SaveManager |
| `niveles/GameSceneRouter.gd` | Cambia la escena activa. Conoce todas las rutas. | Medio — es solo un diccionario de rutas + cambio de escena |
| `sistemas/ModalidadRouter.gd` | Mapea modo string → ruta de escena. | Fácil — solo un match/case |

---

## Archivos legacy (no borrar todavía)

Estos archivos ya no se usan en el flujo principal pero siguen en el repositorio:

| Archivo | Por qué sigue | Cuándo borrar |
|---|---|---|
| `mapas/LevelNode.gd` | Usado por `MapChapterNode.tscn` y `MapQuestionNode.tscn` | Cuando se eliminen esas dos escenas |
| `mapas/MapChapterNode.tscn` | No tiene referencias activas tras limpiar `MapBoard.tscn` | Sprint de cleanup de archivos legacy |
| `mapas/MapQuestionNode.tscn` | Ídem | Ídem |

---

## Verificación rápida (smoke test)

Para confirmar que el mapa sigue funcionando después de un cambio:
```
Abrir el proyecto en Godot
→ Ir al mapa
→ Contar que hay 30 nodos
→ Hacer clic en el nodo 1 → debe abrir actividad
→ Hacer clic en el nodo 30 → debe mostrar "bloqueado"
→ Completar una actividad → debe volver al mapa con badge actualizado
```

Los smoke tests automáticos están en `tests/vertical_slice_smoke_test.gd`.
