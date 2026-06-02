# Auditoría: nodos hardcodeados en MapBoard.tscn

Fecha: Sprint 1 Commit 11 — auditoría previa al vaciado de `MapBoard.tscn`.

---

## Situación detectada

`MapBoard.tscn` tenía 30 nodos hijo hardcodeados bajo `NodesContainer`:

| Grupo | Nombres | Escena base | Script |
|---|---|---|---|
| Capítulos | `Receta1`–`Receta6` | `MapChapterNode.tscn` | `LevelNode.gd` |
| Preguntas | `Pregunta1`–`Pregunta24` | `MapQuestionNode.tscn` | `LevelNode.gd` |

### Propiedades exportadas por cada nodo

| Propiedad | Presente en | Estado |
|---|---|---|
| `nivel_id` | todos (1–30) | secuencial; coincide con posición en JSON |
| `level_number` | solo Recetas | 1–6 |
| `question_number` | solo Preguntas | 1–24 |
| `node_key` | algunos Preguntas | **stale** — keys obsoletos (`"eliminar_gluten"`, etc.) |
| `label_text` | todos | **stale** — `"Receta 1"–"Receta 6"`, `"Pregunta 1"–"Pregunta 24"` |
| `icon_texture` | la mayoría | texturas per-node; sin equivalente en `MapNodeData` |
| `position` | todos | **copia exacta** del JSON |
| `scale` | todos | **copia exacta** del JSON |

---

## Por qué son redundantes

`MapBoard.gd` ya es data-driven desde Sprint 1. En `configurar_nodos()`:

```gdscript
# Limpiar nodos visuales anteriores.
for hijo in contenedor_nodos.get_children():
    hijo.queue_free()  # ← destruye los 30 hardcodeados antes de usarlos
```

Inmediatamente después, instancia 30 × `MapNode.tscn` desde los `MapNodeData` del JSON.
**Ningún dato de los nodos hardcodeados se lee en ningún momento del runtime.**

---

## Posiciones y escalas ya están en el JSON

Sprint 1 Commit 3 migró las coordenadas al JSON como `map_position` y `map_scale`.
`MapBoard.gd` las lee explícitamente:

```gdscript
if node_data.has_map_position:
    visual_node.position = node_data.map_position
if node_data.has_map_scale:
    visual_node.scale = Vector2.ONE * node_data.map_scale
```

Los 30 nodos del JSON tienen `has_map_position = true` y `has_map_scale = true`. No hay nada que migrar.

---

## Confirmación de que MapBoard.gd ya instancia dinámicamente

`MapBoard.gd` carga:
```gdscript
const MapNodeScene := preload("res://mapas/MapNode.tscn")
```
Y en `configurar_nodos()`:
```gdscript
var visual_node: Node2D = MapNodeScene.instantiate()
visual_node.configurar(node_data, node_state)
```

`MapNode.tscn` usa `MapNode.gd` (el script nuevo del Sprint 1), no `LevelNode.gd`.

---

## Riesgos evaluados

| Riesgo | Nivel | Detalle |
|---|---|---|
| Pérdida de posición/escala | 🟢 NINGUNO | Ya están en el JSON |
| Pérdida de `node_key` | 🟢 NINGUNO | Los keys hardcodeados eran stale; el JSON tiene los definitivos |
| Pérdida de `label_text` | 🟢 NINGUNO | `MapNodeData.title` viene del JSON |
| Pérdida de `nivel_id` | 🟢 NINGUNO | Los game scenes lo leen de `ContextoSesionDeJuego` → `Global`, no del nodo visual |
| Ruptura de runtime | 🟢 NINGUNA | Los nodos hardcodeados no se usan en runtime |
| Tiempo de carga | 🟢 MEJORA | Godot deja de cargar y destruir 30 packed scenes en cada instanciación |

---

## Gap identificado: icon_texture per-node

`MapChapterNode.tscn` y `MapQuestionNode.tscn` tenían íconos visuales distintos por nodo.
`MapNode.tscn` no tiene `icon_texture` ni texture asignada en su `Icon` Sprite2D.

**Estado actual aceptado**: los nodos dinámicos ya se renderizan sin ícono per-node.
El shader de hover y los estados de color (disponible/completado/bloqueado) siguen funcionando.

**Deuda futura**: agregar campo `icon_id` o `icon_path` en `MapNodeData` + JSON si se necesita diferenciación visual por tipo o tema de nodo.

---

## Archivos legacy que quedan como deuda

- `MapChapterNode.tscn` — no más referencias activas tras vaciar `MapBoard.tscn`
- `MapQuestionNode.tscn` — ídem
- `LevelNode.gd` — script viejo; solo usado por los dos anteriores
- `mapas/README.md` — sigue mencionando `LevelNode.gd` como parte del stack

Estos archivos no se eliminan en este sprint para no introducir riesgo. Son candidatos para un cleanup dedicado.
