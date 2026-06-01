# Sistema de nodos del mapa

> **Estado del layout (2026-05-31):**
> Las clases `MapPathLayout`, `MapRouteRegistry`, `MapLayoutConfig` y `MapNodePositionResolver`
> están implementadas, conectadas a `MapBoard.configurar_nodos()` y testeadas en el smoke test.
> Los nodos del mapa se posicionan automáticamente sobre la curva `RutaCeliaquia1`.
> La curva tiene **30 puntos** — uno por nodo — usando `placement_mode = "anchors"`.

## Flujo completo — JSON → nodo → partida → progreso

```
celiaquia_mapa.json
  ↓ CargadorDeMapa.load_map()               [mapas/logica/CargadorDeMapa.gd]
  ↓ builds Array[MapNodeData] + MapLayoutConfig
MapScene._ready()                           [mapas/MapScene.gd]
  ↓ cargar_mapa() → nodos_mapa + layout_config
  ↓ actualizar_estados_de_nodos()
  ↓ AvanceDeNodo.get_node_state()           [mapas/logica/AvanceDeNodo.gd]
  ↓ MapBoard.configurar_nodos(nodos_mapa, node_states, layout_config)
  |    ↓ MapNodePositionResolver.resolve(Contenido, layout_config, 30)
  |    |    ↓ MapRouteRegistry.find_route(Contenido, "RutaCeliaquia1")
  |    |    ↓ MapPathLayout.calcular_posiciones_por_anchors(curve, 30)  [modo anchors]
  |    |    |  MapPathLayout.calculate_positions(curve, 30, config)    [modo curve]
  |    ↓ visual_node.position = layout_pos[i] - contenedor_nodos.position
  ↓ LevelNode.configurar(data, state)       [mapas/LevelNode.gd]  ← renderiza
--- jugador toca nodo ---
FlujoDeNodoJugable.seleccionar_nodo()       [flow/map/flujo_de_nodo_jugable.gd]
  ↓ AvanceDeNodo.get_node_state() → is_unlocked?
  ↓ AbridorDeNodoJugable.abrir_nodo()       [mapas/logica/AbridorDeNodoJugable.gd]
  ↓ NodoRuntime.iniciar()                   [sistemas/NodoRuntime.gd]
  ↓ ArmadorDePartida.construir_plan_de_partida(node_data)
  |    ↓ construir_juegos_random / fijos
  |    ↓ _read_used_activity_ids() → SaveManager.get_all_used_activity_ids()
  |    ↓ _filter_final_games_by_history()   ← anti-repetición persistida
  ↓ ContinuidadDePartidaDeNodo.abrir_juego_actual()
  ↓ GameSceneRouter.ir_a_modo_jugable()     ← navega a escena jugable
--- jugador termina minijuego ---
ContinuidadDePartidaDeNodo.continuar_o_finalizar_partida()
  ↓ _marcar_activity_actual_jugada() → SaveManager.mark_activity_played()
  ↓ _guardar_precision_nodo() → SaveManager.save_node_accuracy()
  ↓ _registrar_exp_finalizacion() → SaveManager.add_exp()
--- retorno al mapa ---
MapBoard.refresh_progress_from_save()       ← repinta estrellas/badges
  ↓ LevelNode.configurar(data, state)       ← actualiza visual
```

---

## Nodo visual único

### Estado actual
`LevelNode.gd` es el **único script** que maneja todos los nodos visuales del mapa.

Existen dos scene files que actúan como presets visuales, ambas con `LevelNode.gd` como script:

| Scene | `node_kind` | Icon | Shader en icon | Commits migrados |
|---|---|---|---|---|
| `mapas/MapChapterNode.tscn` | `chapter` (default) | desafio-mapa-8.png | Sí — intro.gdshader (glow radial) | B1, B2 |
| `mapas/MapQuestionNode.tscn` | `question` | desafio-mapa-7.png | No | B1, B3 |

`MapBoard.tscn` instancia 6 × MapChapterNode (Receta1–6) y 24+ × MapQuestionNode (Pregunta1–24) con posiciones manuales.

### Parámetros visuales (`@export_group "Appearance"` en LevelNode.gd)

Todos tienen defaults seguros que no sobreescriben nada si no se setean:

| Export | Tipo | Default | Efecto |
|---|---|---|---|
| `icon_scale` | `Vector2` | `Vector2.ZERO` | Escala del sprite `$Icon`. ZERO = sin override |
| `icon_offset` | `Vector2` | `Vector2.ZERO` | Posición del sprite `$Icon`. ZERO = sin override |
| `icon_material` | `Material` | `null` | Material/shader del sprite. null = sin override |
| `badge_offset` | `Vector2` | `Vector2.ZERO` | Posición del `$NodeProgressBadge`. ZERO = sin override |

Estos valores están seteados en los nodos raíz de `MapChapterNode.tscn` y `MapQuestionNode.tscn`.

### Para cambiar diseño de un nodo
> Ir a `mapas/LevelNode.gd`.

Para cambiar el shader del capítulo: modificar `icon_material` en `MapChapterNode.tscn` (el `ShaderMaterial_a0hgu` referencia `res://niveles/intro.gdshader`).

---

## Armado de partida y selección de actividades

### Flujo
```
ArmadorDePartida.construir_plan_de_partida(node_data)
  ├─ has_fixed_games()  → construir_juegos_fijos()
  ├─ uses_random_games() → construir_juegos_random()
  │    └─ _select_random_game_entries()
  │         └─ _read_used_activity_ids(request_key)  ← lee SaveManager
  │              └─ SaveManager.get_completed_activity_ids(request_key)
  └─ [legacy] construir_juegos_para_nodo()  ← solo anti-repeat local
```

### Anti-repetición (path V1 — activo)
El path `construir_juegos_random` tiene anti-repetición en dos niveles:

| Nivel | Mecanismo | Alcance |
|---|---|---|
| Intra-nodo | `used_activity_ids` dentro del plan | Misma sesión, mismo nodo |
| Cross-sesión | `_read_used_activity_ids(request_key)` → `SaveManager.get_all_used_activity_ids()` | Persistido en disco |
| Sesión actual | `_session_used_activity_ids_by_request` | Volátil (en memoria) |

`request_key` = `"{type}|{difficulty}|{options_count}"`.

Cuando no hay alternativas: emite `push_warning` y usa fallback controlado. No rompe la partida.

### Anti-repetición (path legacy — desaconsejado)
`construir_juegos_para_nodo` evita repetir `json_path` dentro del plan actual, pero no persiste historia. Afecta solo nodos con `json_path` directo sin `games` array.

### Dónde se marca la actividad como completada
`ContinuidadDePartidaDeNodo._marcar_activity_actual_completada()` →
`SaveManager.mark_activity_completed(request_key, activity_id)`

Se llama antes de pasar al siguiente juego en la partida.

### IDs de actividades
- V1 (contenido con `games` array): las actividades tienen `activity_id` único ✅
- Legacy (nodos con `json_path` directo): el ID es la ruta del json — puede repetir si dos nodos apuntan al mismo archivo

---

## Posicionamiento de nodos

### Estado actual

Los nodos del mapa se posicionan automáticamente usando `placement_mode = "anchors"`.
Cada nodo i recibe `RutaCeliaquia1.get_point_position(i)` — el punto i de la Curve2D.

Para cambiar la posición de un nodo: editar el **punto correspondiente** en `RutaCeliaquia1` (`MapBoard.tscn`).

### Pipeline de layout automático (activo)

El flujo completo está conectado y en producción:

```
celiaquia_mapa.json  →  layout.route_id = "RutaCeliaquia1", placement_mode = "anchors"
  → MapLayoutConfig      lee route_id, placement_mode, spacing_factor, márgenes
  → MapRouteRegistry     busca Path2D por nombre dentro del contenedor
  → MapPathLayout        get_point_position(i) por cada nodo i (modo anchors)
  → MapNodePositionResolver  devuelve Array[Vector2] en espacio Contenido
  → MapBoard             posiciona y dibuja
```

### Tabla de referencia rápida (sistema de layout)

| Si quiero... | Voy a... |
|---|---|
| Cambiar la curva activa | `celiaquia_mapa.json` → `layout.route_id` |
| Cambiar la separación entre nodos | `celiaquia_mapa.json` → `layout.spacing_factor` |
| Cambiar el modo de distribución | `celiaquia_mapa.json` → `layout.spacing_mode` |
| Cambiar el algoritmo de distribución | `mapas/layout/MapPathLayout.gd` |
| Revisar la resolución de posición final | `mapas/layout/MapNodePositionResolver.gd` |
| Ver cómo se busca el Path2D | `mapas/layout/MapRouteRegistry.gd` |
| Agregar márgenes en los extremos | `celiaquia_mapa.json` → `layout.start_margin` / `end_margin` |

### Layout automático por ruta — `MapPathLayout.gd`
Helper estático en `mapas/layout/MapPathLayout.gd` (movido de `mapas/logica/` en refactor 2026-05-30).

#### Opción A: Polyline (puntos guia en script/resource)
```gdscript
var puntos := [Vector2(100, 500), Vector2(300, 400), Vector2(500, 350)]
var posiciones := MapPathLayout.calcular_posiciones(puntos, 30)
```

`MapBoard` expone `var ruta_puntos_guia: Array[Vector2] = []`.
Asignarlo antes de `configurar_nodos` activa el layout polyline.

#### Opción B: Curve2D (RutaCeliaquia1 — nativo Godot)
`MapBoard.tscn` tiene un nodo `RutaCeliaquia1 : Path2D` dentro de `ScrollContainer/Contenido`, **invisible** (`visible = false`). Es una herramienta de layout puro, no un elemento visual del juego.

Cómo editar la curva en el editor de Godot:
1. Abrir `MapBoard.tscn`.
2. Seleccionar `ScrollContainer > Contenido > RutaCeliaquia1`.
3. Activar `visible = true` temporalmente para ver la curva mientras se edita.
4. Usar la herramienta "Edit Curve" para agregar puntos sobre la línea del mapa.
5. Volver a `visible = false` antes de guardar.

`MapBoard.gd` usa `MapNodePositionResolverScript.resolve(route_container, layout_config, count)` que detecta la ruta vía `layout_config.route_id`.

### Posicionamiento — cadena de prioridad
1. Si `layout_config` es válido → `MapNodePositionResolver.resolve()` calcula posiciones sobre la curva.
2. Si `node_data.has_map_position == true` → usa `map_position` del JSON.
3. Ninguno de los anteriores → conserva la posición del `.tscn`.

**Estado actual:** `placement_mode = "anchors"`. Los 30 nodos usan `get_point_position(i)` sobre los 30 puntos de `RutaCeliaquia1`.

### Rutas disponibles en `MapBoard.tscn`

| Nodo | Uso | Estado |
|---|---|---|
| `RutaCeliaquia1` | Ruta principal. Trazada sobre el camino gris de `mapa.png`. | ✅ **Activa** — 30 puntos, placement_mode="anchors" |
| `RutaCeliaquia2` | Ruta alternativa de validación. | ✅ Funcional — 17 puntos, S-curve simple |

Ambas rutas están en `ScrollContainer/Contenido`, `position=Vector2.ZERO`, `scale=Vector2.ONE`, `rotation=0`, `visible=false`.

#### Cómo cambiar la ruta activa

Editar `celiaquia_mapa.json`:

```json
"layout": {
  "route_id": "RutaCeliaquia1"
}
```

o

```json
"layout": {
  "route_id": "RutaCeliaquia2"
}
```

No se requiere ningún cambio en código. `MapBoard` lee `route_id` en runtime vía `MapRouteRegistry`.

#### Cómo ajustar separación

```json
"layout": {
  "route_id": "RutaCeliaquia1",
  "spacing_mode": "space_around",
  "spacing_factor": 1.0,
  "start_margin": 40.0,
  "end_margin": 40.0
}
```

#### Tabla de referencia rápida

| Quiero... | Voy a... |
|---|---|
| Editar la ruta principal | `MapBoard.tscn > ScrollContainer/Contenido/RutaCeliaquia1` |
| Editar la ruta alternativa | `MapBoard.tscn > ScrollContainer/Contenido/RutaCeliaquia2` |
| Cambiar ruta activa | `celiaquia_mapa.json > layout.route_id` |
| Cambiar separación | `celiaquia_mapa.json > layout.spacing_factor` |
| Cambiar modo de espaciado | `celiaquia_mapa.json > layout.spacing_mode` |
| Cambiar algoritmo | `mapas/layout/MapPathLayout.gd` |
| Revisar ruta encontrada | `mapas/layout/MapRouteRegistry.gd` |
| Revisar posición final | `mapas/layout/MapNodePositionResolver.gd` |

Para editar la curva activa: `MapBoard.tscn` → `ScrollContainer/Contenido/RutaCeliaquia1`, activar `visible = true` temporalmente.


---

## Arquitectura `mapas/layout/` (refactor 2026-05-30)

### Archivos del módulo

| Archivo | Clase | Responsabilidad |
|---|---|---|
| `mapas/layout/MapPathLayout.gd` | `MapPathLayout` | Cálculo matemático de posiciones sobre curvas/polylines. Stateless. |
| `mapas/layout/MapLayoutConfig.gd` | `MapLayoutConfig` | Configuración de spacing: mode, factor, márgenes, route_id. Parseable desde JSON. |
| `mapas/layout/MapNodePositionResolver.gd` | `MapNodePositionResolver` | Asigna posiciones a nodos: curva > fallback base del .tscn. |
| `mapas/layout/MapRouteRegistry.gd` | `MapRouteRegistry` | Busca Path2D por nombre en el contenedor del mapa; devuelve Curve2D. |

### Sección `layout` en el JSON del mapa

```json
"layout": {
  "route_id": "RutaCeliaquia1",
  "spacing_mode": "even",
  "spacing_factor": 1.0,
  "start_margin": 0.0,
  "end_margin": 0.0
}
```

Todos los campos son opcionales — tienen defaults seguros.

#### Modos de espaciado (`spacing_mode`)

| Modo | Descripción |
|---|---|
| `"even"` | Equidistante de inicio a fin. Primer y último en los extremos. |
| `"space_between"` | Igual que `even` (primer/último en bordes; intermedios equidistantes). |
| `"space_around"` | Deja medio-paso de margen en inicio y final. Los nodos no tocan los extremos de la curva. |

#### `spacing_factor`
Comprime (`< 1.0`) o expande (`> 1.0`) el intervalo central de la distribución, siempre dentro del rango `[0..1]`. Default `1.0` = sin compresión.

### Cómo agregar una tercera curva

1. En `MapBoard.tscn`, dentro de `NodesContainer`, agregar un nuevo nodo `Path2D` con nombre único (e.g. `"RutaExtra"`).
2. Trazar la curva en el editor.
3. En el JSON del mapa, setear `"layout": {"route_id": "RutaExtra"}`.
4. `MapBoard` usará esa curva automáticamente vía `MapRouteRegistry`.
5. Si el nodo no existe o está vacío, `MapRouteRegistry` registra un warning y hace fallback a posición del `.tscn`.

### Integración con `MapBoard` (pendiente)

`MapBoard.configurar_nodos()` actualmente **no llama a ninguna clase de layout**.
Los nodos usan posición del `.tscn`. Para activar el layout automático, hay que conectar:
1. `MapScene.cargar_mapa()` → parsear `layout_config` del JSON e inyectarlo en `map_board`.
2. `MapBoard.configurar_nodos()` → llamar `_obtener_curva_activa()` → `MapRouteRegistry`.
3. `MapBoard.configurar_nodos()` → llamar `MapNodePositionResolver.calcular_posiciones_para_nodos()`.
4. Por nodo: `visual_node.position = MapNodePositionResolver.obtener_posicion_para_nodo(...)`.

---

## ArmadorDePartida — Certificación anti-repetición (2026-05-30)

| Función | Estado |
|---|---|
| `_filter_final_games_by_history(node_key, final_games)` | ✅ Certificado — filtra actividades ya jugadas/completadas |
| `_read_used_activity_ids(request_key)` | ✅ Certificado — preferencia a SaveManager, con fallbacks |
| `_filter_unavailable_activity_candidates(candidates, used_ids, history_ids)` | ✅ Certificado — filtra tanto IDs del nodo actual como del SaveManager |
| `_session_used_activity_ids_by_request` | ✅ Anti-repetición dentro de la sesión activa |
| Pool exhausto → `push_warning` + return `{}` | ✅ No crashea |
| Tests de cobertura | ✅ 5 tests en suite `[ContentId]`: pool_agotado, filtra_ids_jugados, no_resetea, save_manager precision |

#### Opción A: Polyline (puntos guia en script/resource)
```gdscript
var puntos := [Vector2(100, 500), Vector2(300, 400), Vector2(500, 350)]
var posiciones := MapPathLayout.calcular_posiciones(puntos, 30)
```

`MapBoard` expone `var ruta_puntos_guia: Array[Vector2] = []`.
Asignarlo antes de `configurar_nodos` activa el layout polyline.

#### Opción B: Curve2D (RutaCeliaquia1 — nativo Godot)
`MapBoard.tscn` tiene un nodo `RutaCeliaquia1 : Path2D` dentro de `ScrollContainer/Contenido`, **invisible** (`visible = false`). Es una herramienta de layout puro, no un elemento visual del juego.

Cómo trazar la curva en el editor de Godot:
1. Abrir `MapBoard.tscn`.
2. Seleccionar `ScrollContainer > Contenido > RutaCeliaquia1`.
3. Activar `visible = true` temporalmente para ver la curva mientras se edita.
4. Usar la herramienta "Edit Curve" para agregar puntos sobre la línea del mapa.
5. Volver a `visible = false` antes de guardar.

`MapBoard.gd` llama `MapNodePositionResolverScript.resolve(route_container, layout_config, count)` que detecta la ruta activa.

```gdscript
# En MapBoard.gd — cálculo automático sin código extra
# Solo requiere tener puntos en RutaCeliaquia1.curve
```

También se puede llamar directamente:
```gdscript
var largo: float = curva.get_baked_length()
var posiciones := MapPathLayout.calcular_posiciones_en_curva(curva, 30)
# Opcional: márgenes en píxeles desde los extremos
var posiciones_con_margen := MapPathLayout.calcular_posiciones_en_curva(curva, 30, 80.0, 80.0)
```

#### Cadena de prioridad (implementada en `obtener_posiciones_de_ruta` + `resolver_posicion_nodo`)
1. `node_data.has_map_position == true` → usa `map_position` del JSON (siempre gana)
2. `RutaCeliaquia1.curve` tiene longitud > 0 → usa `calcular_posiciones_en_curva`
3. `ruta_puntos_guia` no vacío → usa `calcular_posiciones` (polyline)
4. Ninguno de los anteriores → conserva la posición hardcodeada del `.tscn`

#### Cómo migrar gradualmente del layout manual al automático
- Los 30 nodos actuales tienen posición hardcodeada en `MapBoard.tscn`. Siguen funcionando sin cambios.
- Para migrar un nodo al layout automático: quitar `map_position` de su `MapNodeData` (o no setearlo en el JSON). El sistema cae al layout de curva.
- Para forzar posición manual en cualquier nodo: setear `map_position` en el JSON. Siempre gana.
- Coexistencia: algunos nodos con posición manual + otros sobre la curva funciona correctamente.

---

## Prueba controlada del layout automático (verificada 2026-05-30)

### Escenario probado
5 nodos simulados con una curva de 4 puntos (forma S, cubre la zona superior del mapa):
- Punto 1: `(960, 297)` — zona Receta 1
- Punto 2: `(804, 415)` — zona Pregunta 1
- Punto 3: `(571, 400)` — zona Receta 2
- Punto 4: `(329, 443)` — zona Pregunta 2/3

2 nodos con `map_position` manual (`Receta1`, `Receta2`). 3 nodos sin `map_position` (`Pregunta1`, `Pregunta2`, `Pregunta3`).

### Resultado headless (exit 0, 23 tests MapPath âœ“)
```
nodo0 Receta1(manual)   → (960.0, 297.0)      ← posición manual respetada exactamente
nodo1 Pregunta1(auto)   → (825.4402, 398.7823) ← calculada por la curva
nodo2 Receta2(manual)   → (571.0, 400.0)       ← posición manual respetada exactamente
nodo3 Pregunta2(auto)   → (495.1166, 413.4834) ← calculada por la curva
nodo4 Pregunta3(auto)   → (329.0, 443.0)       ← calculada por la curva (final de ruta)
```

### Conclusiones
- **La prioridad manual → curva → tscn funciona correctamente.** Los 2 nodos manuales no se movieron ni un píxel.
- **Los 3 nodos automáticos se distribuyeron equidistantemente** a lo largo de la curva (índices 1, 3, 4 de una distribución de 5 sobre la curva completa).
- **Sin curva:** los 3 nodos conservaron su base del `.tscn` (confirmado con suite `_test_integracion_sin_curva_todos_conservan_base`).
- **Curve2D vacía** (RutaCeliaquia1 sin dibujar) actúa como fallback seguro — ningún nodo se mueve.
- La curva simulada cubre aprox. 700px horizontales y 150px verticales. El espaciado automático resultó uniforme.

### Sobre la curva real (actualizado 2026-05-30)
`RutaCeliaquia1` en `MapBoard.tscn` tiene **77 puntos** trazados sobre el camino gris de `mapa.png` (1118×1920 px). Los puntos siguen la ruta serpentina completa desde "Inicio" (top-right) hasta "fin" (bottom-right).

> La tabla de 30 waypoints manuales ya no aplica — las posiciones son calculadas por `MapPathLayout.calculate_positions()` distribuyendo 30 nodos a lo largo de la curva de 77 puntos.

| Punto | Posición | Nodo visual |
|---|---|---|
| 0 | (960, 297) | Receta 1 (inicio) |
| 1 | (804, 415) | Pregunta 1 |
| 2 | (571, 400) | Receta 2 |
| 3 | (329, 443) | Pregunta 2 |
| 4 | (282, 636) | Receta 3 |
| 5 | (459, 745) | Pregunta 3 |
| 6 | (700, 708) | Receta 4 |
| 7 | (942, 745) | Pregunta 4 |
| 8 | (942, 946) | Receta 5 |
| 9 | (804, 1071) | Pregunta 5 |
| 10 | (612, 1020) | Receta 6 |
| 11 | (394, 994) | Pregunta 6 |
| 12 | (213, 1088) | Pregunta 7 |
| 13 | (252, 1385) | Pregunta 8 |
| 14 | (562, 1432) | Pregunta 9 ← inicio del rulo |
| 15 | (759, 1280) | Pregunta 10 ← backtrack Y sube |
| 16 | (942, 1355) | Pregunta 11 |
| 17 | (942, 1549) | Pregunta 12 |
| 18 | (750, 1651) | Pregunta 13 |
| 19 | (552, 1651) | Pregunta 14 |
| 20 | (329, 1598) | Pregunta 15 |
| 21 | (174, 1701) | Pregunta 16 |
| 22 | (331, 1962) | Pregunta 17 |
| 23 | (593, 1928) | Pregunta 18 |
| 24 | (840, 1962) | Pregunta 19 |
| 25 | (824, 2222) | Pregunta 20 |
| 26 | (638, 2397) | Pregunta 21 ← inicio del segundo rulo |
| 27 | (301, 2276) | Pregunta 22 ← backtrack Y sube |
| 28 | (270, 2589) | Pregunta 23 |
| 29 | (638, 2695) | Pregunta 24 (fin) |

**Por qué 77:** la curva sigue el centro del camino gris de `mapa.png` con resolución suficiente para capturar todos los giros, rulos y cambios de dirección. Los 30 nodos se distribuyen uniformemente sobre la longitud de arco de la curva completa mediante `MapPathLayout.calculate_positions()`.

---

## Tabla: Si quiero cambiar / hacer X, voy a Y
### Referencia rápida

| Si quiero cambiar… | Voy a… |
|---|---|
| Datos del mapa (nodos, orden, layout) | `contenido/mapa/celiaquia_mapa.json` |
| Cómo se lee y convierte el JSON | `mapas/logica/CargadorDeMapa.gd` |
| Datos de un nodo (node_key, title, games…) | `mapas/core/MapNodeData.gd` |
| Lógica de estados (quién está bloqueado/disponible/completado) | `mapas/logica/AvanceDeNodo.gd` → llamado desde `MapScene.actualizar_estados_de_nodos()` |
| Render de nodos en el mapa | `mapas/MapBoard.gd` → `configurar_nodos()` |
| Curva activa usada para distribuir nodos | `contenido/mapa/celiaquia_mapa.json` → `"layout": {"route_id": "RutaCeliaquia1"}` |
| Algoritmo de distribución sobre la curva | `mapas/layout/MapPathLayout.gd` → `calcular_posiciones_en_curva()` |
| Resolución de posición por nodo | `mapas/layout/MapNodePositionResolver.gd` → `obtener_posicion_para_nodo()` |
| Visual del nodo individual | `mapas/LevelNode.gd` → `configurar()` + `update_view()` |

### Detalle completo
| Quiero... | Archivo / Acción |
|---|---|
| Mover un nodo manualmente | Editar `map_position` en el JSON del mapa, o `position` en `MapBoard.tscn` |
| Usar layout automático por curva para un nodo | No setear `map_position` (o quitarlo del JSON) y tener puntos en `RutaCeliaquia1` |
| Cambiar la curva del mapa | Seleccionar `RutaCeliaquia1` en `MapBoard.tscn` y editar los puntos |
| Cambiar modo de espaciado (even/space_between/space_around) | `"layout": {"spacing_mode": "space_around"}` en el JSON del mapa |
| Cambiar factor de compresión/expansión del spacing | `"layout": {"spacing_factor": 0.8}` en el JSON del mapa |
| Cambiar márgenes inicio/final de la curva | `"layout": {"start_margin": 80.0, "end_margin": 80.0}` en el JSON |
| Usar una segunda curva | Agregar Path2D en tscn + `"layout": {"route_id": "NombreCurva"}` en JSON |
| Cambiar lógica de distribución sobre la curva | `mapas/layout/MapPathLayout.gd` → `calcular_posiciones_en_curva` |
| Cambiar lógica de spacing | `mapas/layout/MapPathLayout.gd` → `calcular_distancias_normalizadas` |
| Cambiar la prioridad manual vs automático | `mapas/layout/MapNodePositionResolver.gd` → `obtener_posicion_para_nodo` |
| Buscar Path2D por nombre (lookup de ruta) | `mapas/layout/MapRouteRegistry.gd` → `obtener_curva` |
| Ver/editar la curva en el editor | Activar `visible = true` en `RutaCeliaquia1`, editar, volver a `false` |
| Diseño / comportamiento general del nodo | `mapas/LevelNode.gd` |
| Shader del nodo capítulo | `mapas/MapChapterNode.tscn` → `icon_material` (ShaderMaterial inline) |
| Escala o posición del ícono (Chapter) | `mapas/MapChapterNode.tscn` → exports `icon_scale`, `icon_offset` |
| Escala o posición del ícono (Question) | `mapas/MapQuestionNode.tscn` → exports `icon_scale`, `icon_offset` |
| Icono de un nodo específico del mapa | Instancia en `mapas/MapBoard.tscn` → `icon_texture` |
| Agregar nuevo nodo al mapa | `mapas/MapBoard.tscn` + `contenido/mapa/celiaquia_mapa.json` |
| Activar layout automático por polyline (sin editor) | `mapas/MapBoard.gd` → asignar `ruta_puntos_guia` antes de `configurar_nodos` |
| Armado del plan de juegos | `mapas/logica/ArmadorDePartida.gd` |
| Anti-repetición de actividades | `mapas/logica/ArmadorDePartida.gd` → `_read_used_activity_ids` + `_filter_unavailable_activity_candidates` |
| Historial jugadas/completadas persistido | `interface/SaveManager.gd` → `mark_activity_played`, `mark_activity_completed` |
| Obtener todas las actividades usadas | `interface/SaveManager.gd` → `get_all_used_activity_ids` |
| Loader de actividades por modo | `sistemas/contenido/NodeContentLoader.gd` |
| Progreso visual del nodo (estrellas/badge) | `mapas/components/NodeProgressBadge.gd` |
| Revisar precisión/EXP guardada de un nodo | `interface/SaveManager.gd` → `save_node_accuracy`, `get_node_progress_entry` |
| Revisar si el nodo está completado (estrella) | `mapas/logica/AvanceDeNodo.gd` → `is_node_completed()` → `Global.es_nodo_jugable_completado()` |
| Fórmula de EXP por partida | `mapas/logica/ContinuidadDePartidaDeNodo.gd` → `_registrar_exp_finalizacion` → `NodoProgressionRules.gd` |
| Navegación entre escenas jugables | `sistemas/NodoRuntime.gd` + `GameSceneRouter` |

---

## Certificación final del sistema (2026-05-30)

### B — Nodo visual único ✅
`LevelNode.gd` es el **único script** para todos los nodos del mapa. `MapChapterNode.tscn` y `MapQuestionNode.tscn` son presets del mismo nodo (patrón idiomático Godot). Crear un tercer `MapNode.tscn` canónico requeriría reescribir 30 instances en `MapBoard.tscn` sin verificación visual — riesgo alto, beneficio cero. **Bloqueado por seguridad. Estado: cerrado a nivel de script.**

### C — ArmadorDePartida / anti-repetición ✅
| Garantía | Mecanismo | Verificado |
|---|---|---|
| No repite dentro del nodo | `used_activity_ids` en plan actual | `_test_armador_progresion_ids_unicos` |
| No repite ya jugados (si hay alternativa) | `_filter_final_games_by_history` + `SaveManager.get_all_used_activity_ids()` | `_test_armador_filtra_ids_jugados_y_completados` |
| Fallback pool agotado no crashea | Plan devuelve `{}`, log `pool_exhausted`, no excepción | `_test_armador_pool_agotado_no_crashea` |
| SaveManager registra played/completed | `mark_activity_played` + `mark_activity_completed` → disco | `_test_save_manager_guarda_played_y_completed_por_id` |
| EXP/dificultad no cambia en el plan | `construir_plan_de_partida` no toca `total_exp` ni modifica dificultad original | verificado por lectura de código |
| `completed` no fuerza 100% | `save_node_accuracy` guarda `last_accuracy` real, `best_percent` = máximo acumulado | `_test_save_manager_precision_no_forzada_al_100` |

### D — Layout automático ✅
Dos rutas funcionales en `MapBoard.tscn`, ambas en `ScrollContainer/Contenido/NodesContainer`:

| Ruta | Puntos | Largo | Descripción |
|---|---|---|---|
| `RutaCeliaquia1` | 30 | ~7053 px | Copia exacta de la línea visual del mapa, incluye rulos (Y: 297 → 2695) |
| `RutaCeliaquia2` | 14 | ~3993 px | Zigzag regular alternativo sin rulos (Y: 297 → 2695) |

Ambas tienen `position=Vector2.ZERO`, `scale=Vector2.ONE`, `rotation=0`, `visible=false`.
Todos los nodos usan posición automática. Prioridad: `Curve2D activa > polyline > tscn base`.
La ruta activa se elige con `layout.route_id` en el JSON.

---

## Diagnóstico de alineación de RutaCeliaquia1

### Principios

- `Curve2D.sample_baked(distancia)` devuelve coordenadas **locales** al nodo `Path2D`. Si el `Path2D` tiene `position = Vector2(0,0)` relativo a su padre, esas coordenadas son directamente coordenadas del padre.
- **Ruta y nodos visuales deben estar en el mismo parent** para que `visual_node.position = sample_baked(t)` sea correcto sin conversión adicional.
- `RutaCeliaquia1.position` debe ser **Vector2.ZERO**. Si no lo es, todas las posiciones calculadas quedan desplazadas.
- Los puntos de la curva deben estar en **coordenadas de `Contenido`** (el padre de `RutaCeliaquia1`). `MapBoard` resta `contenedor_nodos.position` para convertir al espacio local de `NodesContainer`.
- `MapBoard` instancia nodos dentro de `NodesContainer` y asigna `visual_node.position = layout_pos[i] - contenedor_nodos.position`.
- **Si los nodos salen corridos: revisar parent/offset/scale/rotation antes de tocar el algoritmo.**

### Checklist de diagnóstico

| Propiedad | Valor esperado | Cómo verificar |
|---|---|---|
| `RutaCeliaquia1` es hijo de `NodesContainer` | ✅ | Scene tree en editor |
| `RutaCeliaquia1` es `Path2D` | ✅ | Tipo en inspector |
| `RutaCeliaquia1.position` | `Vector2(0, 0)` | Inspector → Transform |
| `RutaCeliaquia1.scale` | `Vector2(1, 1)` | Inspector → Transform |
| `RutaCeliaquia1.rotation` | `0` | Inspector → Transform |
| `RutaCeliaquia1.visible` | `false` en producción | Inspector |
| `curve.point_count` | ≥ 20 | Script o inspector |
| `curve.get_baked_length()` | > 0 | Script |

### Tabla de problemas visuales

| Problema visual | Causa probable | Archivo / nodo a revisar |
|---|---|---|
| Nodos siguen curva pero corridos | Parent distinto u offset de Path2D | `MapBoard.tscn` / `RutaCeliaquia1` |
| Nodos no siguen la línea gris | Curva mal trazada / pocos puntos | `RutaCeliaquia1.curve` |
| Nodos amontonados en rulos | Rulos no representados en la curva | Waypoints de `RutaCeliaquia1.curve` |
| Cambiar curva no mueve nodos | `route_id` incorrecto o registry mal | JSON layout / `MapRouteRegistry.gd` |
| Primer/último nodo mal ubicados | Puntos extremos equivocados | JSON layout / puntos de curva |
| Nodos bien pero escala rara | `RutaCeliaquia1.scale != Vector2.ONE` | `MapBoard.tscn` → Transform |
| Estados (locked/available/completed) en nodo equivocado | `node_states` era Array indexado positicionalmente; con distinto orden de `visual_nodes` ↔ `map_nodes` el estado se asignaba al visual equivocado | **Corregido (2026-05-30)**: `node_states` es ahora `Dictionary` indexado por `node_key`. Ver sección _Sincronización de estados_. |

### Función de debug disponible en MapBoard.gd

`MapBoard.gd` expone `var debug_layout: bool = false`. Para activar el diagnóstico en sesión de editor:

```gdscript
# En la escena o desde el inspector temporalmente:
map_board.debug_layout = true
map_board.debug_layout_mapa()    # route_id, ruta, transform, puntos, largo, primeras/últimas 5 posiciones
map_board.debug_ruta_y_nodos()   # punto a punto de RutaCeliaquia1
```

Al activar `debug_layout = true`, `configurar_nodos()` imprime una línea por nodo:

```
[MapBoard] i=0 key=celiaquia_01_desayuno_basico pos=(960, 297) state=available completed=false unlocked=true
[MapBoard] i=1 key=celiaquia_02_... pos=(880, 380) state=locked completed=false unlocked=false
...
```

Ambas funciones son no-op si `debug_layout == false`. **No llamar en producción.** No hay código de diagnóstico que se ejecute automáticamente.

### Sincronización de estados de nodos (fix 2026-05-30)

**Problema detectado**: Los estados visuales (locked / available / completed) se asignaban por índice posicional. Si el orden de `visual_nodes` (por `nivel_id`) difería del orden de `map_nodes` (por clave JSON numérica), el estado del nodo N se pintaba sobre el nodo visual N+x equivocado.

**Causa raíz**: `_get_node_state(node_states, index)` usaba el array `node_states` indexado por posición, correlacionando `visual_nodes[i]` con `node_states[i]` sin validar que el `node_key` coincidiera.

**Solución aplicada**:
- `MapScene.actualizar_estados_de_nodos()`: construye `node_states: Dictionary` indexado por `node_key` (antes era `Array[Dictionary]`).
- `MapBoard.configurar_nodos(map_nodes, node_states: Dictionary)`: en el loop extrae `node_key` del `map_nodes[i]` y hace `_get_node_state(node_states, node_key)` por clave.
- `MapBoard._get_node_state(node_states: Dictionary, node_key: String)`: devuelve `node_states.get(node_key, {})`.

Con este cambio el estado de cada nodo va siempre al nodo visual correcto, independientemente del orden en que Godot devuelva los nodos hijos o del orden en que el JSON enumere los nodos.

### Estado actual confirmado (2026-05-30)

| Propiedad | Valor real | Estado |
|---|---|---|
| Parent de `RutaCeliaquia1` | `ScrollContainer/Contenido/NodesContainer` | ✅ correcto |
| Tipo | `Path2D` | ✅ correcto |
| `position` | no declarado = `Vector2(0,0)` | ✅ correcto |
| `scale` | no declarado = `Vector2(1,1)` | ✅ correcto |
| `rotation` | no declarado = `0` | ✅ correcto |
| `visible` | `false` | ✅ correcto |
| `curve.point_count` | **30** | ✅ correcto |
| `curve.get_baked_length()` | ~7053 px | ✅ correcto |
| Primer punto | `(960, 297)` | ✅ = posición de Receta1 |
| Último punto | `(638, 2695)` | ✅ = posición de Pregunta24 |
| Rulos representados | sí (14→15 y 26→27 retrotraso en Y) | ✅ correcto |

**Estado de RutaCeliaquia2 (2026-05-30):**

| Propiedad | Valor real | Estado |
|---|---|---|
| Parent | `ScrollContainer/Contenido/NodesContainer` | ✅ correcto |
| Tipo | `Path2D` | ✅ correcto |
| `position` | `Vector2(0,0)` | ✅ correcto |
| `scale` | `Vector2(1,1)` | ✅ correcto |
| `rotation` | `0` | ✅ correcto |
| `visible` | `false` | ✅ correcto |
| `curve.point_count` | **17** | ✅ correcto |
| `curve.get_baked_length()` | > 0 px | ✅ correcto |
| Patrón | S-curve simple (validación) | ✅ distinta a R1 |
| Progreso de desbloqueo de nodos | `mapas/logica/AvanceDeNodo.gd` |
| EXP y cálculo de precisión | `sistemas/NodoProgressionRules.gd` |
| Apertura de nodo desde el mapa | `mapas/logica/AbridorDeNodoJugable.gd` |
