extends Node2D

const MapPathLayoutScript := preload("res://mapas/layout/MapPathLayout.gd")
const MapRouteRegistryScript := preload("res://mapas/layout/MapRouteRegistry.gd")
const DebugLayoutOverlayScript := preload("res://mapas/debug/DebugLayoutOverlay.gd")

signal node_selected(node_data: MapNodeData)

@export var debug_layout: bool = false

var _configured_node_states: Array[Dictionary] = []

@onready var contenedor_scroll: ScrollContainer = $ScrollContainer
@onready var contenedor_nodos: Node2D = $ScrollContainer/Contenido/NodesContainer
@onready var titulo_del_nivel: Sprite2D = $"Titulo del Nivel"


func _ready() -> void:
	_ocultar_nodos_runtime_hasta_configurar()
	titulo_del_nivel.modulate = Color("#42785e")
	_ajustar_scroll_al_viewport()

func _ajustar_scroll_al_viewport() -> void:
	if contenedor_scroll == null:
		return
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	contenedor_scroll.size.y = maxf(100.0, viewport_height - contenedor_scroll.position.y)


func obtener_contenedor_nodos() -> Node2D:
	return contenedor_nodos


func obtener_scroll_vertical() -> int:
	if contenedor_scroll == null:
		return 0
	return int(contenedor_scroll.scroll_vertical)


func establecer_scroll_vertical(scroll_value: int) -> void:
	if contenedor_scroll == null:
		return
	var max_scroll: int = int(contenedor_scroll.get_v_scroll_bar().max_value)
	contenedor_scroll.scroll_vertical = clampi(scroll_value, 0, max_scroll)


func configurar_nodos(
		map_nodes: Array,
		node_states: Array[Dictionary],
		layout_config: MapLayoutConfig = null) -> void:
	_configured_node_states = node_states.duplicate()
	var visual_nodes: Array[Node2D] = obtener_nodos_runtime_mapa()
	var visible_count: int = mini(visual_nodes.size(), map_nodes.size())
	print_debug("[MapBoard] configurar_nodos count=", visible_count)

	if visual_nodes.size() != map_nodes.size():
		push_warning(
			"MapBoard: cantidad de nodos visuales (%d) distinta a nodos del JSON (%d)."
			% [visual_nodes.size(), map_nodes.size()]
		)

	var layout_positions: Array[Vector2] = []
	if layout_config != null and layout_config.es_valido() and contenedor_nodos != null:
		layout_positions = MapPathLayoutScript.resolver(
			contenedor_nodos, layout_config, map_nodes.size()
		)

	for visual_node in visual_nodes:
		visual_node.hide()

	var estados_por_clave: Dictionary = _construir_estados_por_clave(map_nodes, node_states)

	for index in range(visible_count):
		var visual_node: Node2D = visual_nodes[index]
		var node_data: MapNodeData = map_nodes[index] as MapNodeData
		var node_state: Dictionary = _obtener_estado_para_nodo(
			node_data, node_states, index, estados_por_clave
		)
		if node_data == null or not node_data.es_valido():
			continue

		if "node_key" in visual_node:
			visual_node.set("node_key", node_data.node_key)
		if "nivel_id" in visual_node:
			visual_node.set("nivel_id", node_data.order)
		visual_node.show()
		if index < layout_positions.size():
			visual_node.position = layout_positions[index]
		elif node_data.has_map_position:
			visual_node.position = node_data.map_position
		if visual_node.has_method("configurar"):
			visual_node.configurar(node_data, node_state)
		var callback := Callable(self, "_on_visual_node_selected")
		var already_connected := visual_node.is_connected("selected", callback)
		if visual_node.has_signal("selected") and not already_connected:
			visual_node.connect("selected", callback)

	for index in range(visible_count, visual_nodes.size()):
		visual_nodes[index].hide()

	_actualizar_debug_overlay(layout_positions, layout_config)


func _actualizar_debug_overlay(
		positions: Array[Vector2], layout_config: MapLayoutConfig = null) -> void:
	const OVERLAY_NAME := "DebugLayoutOverlay"
	if contenedor_nodos == null:
		return
	var old: Node = contenedor_nodos.get_node_or_null(OVERLAY_NAME)
	if old:
		old.queue_free()
	var route_id := layout_config.route_id if layout_config != null and layout_config.es_valido() else ""
	var ruta: Path2D = null
	if not route_id.is_empty():
		ruta = MapRouteRegistryScript.buscar_ruta(contenedor_nodos, route_id)
	if ruta:
		ruta.visible = debug_layout
	if not debug_layout:
		return
	var overlay: DebugLayoutOverlay = DebugLayoutOverlayScript.new()
	overlay.name = OVERLAY_NAME
	overlay.z_index = 200
	contenedor_nodos.add_child(overlay)
	overlay.establecer_posiciones(positions)


func actualizar_progreso_desde_guardado() -> void:
	print_debug("[MapBoard] actualizar_progreso_desde_guardado()")
	var visual_nodes: Array[Node2D] = obtener_nodos_runtime_mapa()
	var visible_count: int = mini(visual_nodes.size(), _configured_node_states.size())
	for index in range(visible_count):
		var visual_node: Node2D = visual_nodes[index]
		if visual_node == null:
			continue
		var node_state: Dictionary = _obtener_estado_nodo(_configured_node_states, index)
		var completed: bool = bool(node_state.get("is_completed", false))
		var saved_percent: float = float(node_state.get("best_percent", 0.0))
		if completed and visual_node.has_method("establecer_progreso_estrella"):
			visual_node.call("establecer_progreso_estrella", saved_percent)



func _ocultar_nodos_runtime_hasta_configurar() -> void:
	if contenedor_nodos == null:
		return
	for visual_node in obtener_nodos_runtime_mapa():
		visual_node.hide()


func obtener_nodos_runtime_mapa() -> Array[Node2D]:
	var nodos_ordenados: Array[Node2D] = []
	for nodo_hijo in contenedor_nodos.get_children():
		var nodo_mapa: Node2D = nodo_hijo as Node2D
		if nodo_mapa == null:
			continue
		if not nodo_mapa.has_method("configurar"):
			continue
		nodos_ordenados.append(nodo_mapa)

	nodos_ordenados.sort_custom(Callable(self, "_ordenar_por_nivel_id"))
	return nodos_ordenados


func _ordenar_por_nivel_id(a: Node2D, b: Node2D) -> bool:
	return int(a.get("nivel_id")) < int(b.get("nivel_id"))


func _on_visual_node_selected(node_data: RefCounted) -> void:
	if node_data is MapNodeData:
		node_selected.emit(node_data as MapNodeData)


func _obtener_estado_nodo(node_states: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= node_states.size():
		return {}
	return node_states[index]


func _construir_estados_por_clave(
		map_nodes: Array,
		node_states: Array[Dictionary]) -> Dictionary:
	var estados_por_clave: Dictionary = {}
	var limite: int = mini(map_nodes.size(), node_states.size())
	for index in range(limite):
		var node_data: MapNodeData = map_nodes[index] as MapNodeData
		if node_data == null:
			continue
		var clave: String = node_data.node_key.strip_edges()
		if clave.is_empty():
			continue
		estados_por_clave[clave] = node_states[index]
	return estados_por_clave


func _obtener_estado_para_nodo(
		node_data: MapNodeData,
		node_states: Array[Dictionary],
		index: int,
		estados_por_clave: Dictionary) -> Dictionary:
	if node_data != null:
		var clave: String = node_data.node_key.strip_edges()
		if not clave.is_empty() and estados_por_clave.has(clave):
			return estados_por_clave[clave] as Dictionary
	return _obtener_estado_nodo(node_states, index)


func desplazar_al_nodo_recomendado() -> void:
	if contenedor_scroll == null or contenedor_nodos == null:
		return
	var visual_nodes: Array[Node2D] = obtener_nodos_runtime_mapa()
	for visual_node in visual_nodes:
		if visual_node.has_method("es_leccion_actual") and bool(visual_node.call("es_leccion_actual")):
			_desplazar_a_nodo.call_deferred(visual_node)
			return
	desplazar_al_primer_nodo_disponible()


func desplazar_al_primer_nodo_disponible() -> void:
	if contenedor_scroll == null or contenedor_nodos == null:
		return
	var visual_nodes: Array[Node2D] = obtener_nodos_runtime_mapa()
	for visual_node in visual_nodes:
		if bool(visual_node.get("unlocked")) and not bool(visual_node.get("completed")):
			_desplazar_a_nodo.call_deferred(visual_node)
			return


func _desplazar_a_nodo(visual_node: Node2D) -> void:
	if contenedor_scroll == null or not is_instance_valid(visual_node):
		return
	var scroll_target: int = int(
		visual_node.global_position.y
		- contenedor_scroll.global_position.y
		+ contenedor_scroll.scroll_vertical
		- contenedor_scroll.size.y * 0.4
	)
	establecer_scroll_vertical(scroll_target)


func debug_ruta_y_nodos(layout_config: MapLayoutConfig = null) -> void:
	if not debug_layout or contenedor_nodos == null:
		return
	var route_id := "RutaCeliaquia1"
	if layout_config != null and layout_config.es_valido():
		route_id = layout_config.route_id
	var ruta: Path2D = MapRouteRegistryScript.buscar_ruta(contenedor_nodos, route_id)
	if ruta == null:
		printerr(
			"[MapBoard] debug_ruta_y_nodos: ruta '%s' no encontrada en %s/%s"
			% [route_id, contenedor_nodos.name, MapRouteRegistryScript.ROUTES_FOLDER]
		)
		return
	var curva := ruta.curve
	print("[MapBoard] NODES_CONTAINER local:", contenedor_nodos.position)
	print("[MapBoard] NODES_CONTAINER global:", contenedor_nodos.global_position)
	print("[MapBoard] RUTA local:", ruta.position)
	print("[MapBoard] RUTA global:", ruta.global_position)
	print("[MapBoard] RUTA scale:", ruta.scale)
	print("[MapBoard] RUTA rotation:", ruta.rotation)
	if curva == null:
		printerr("[MapBoard] debug_ruta_y_nodos: ruta '%s' sin curva" % route_id)
		return
	print("[MapBoard] LARGO curva:", curva.get_baked_length())
	print("[MapBoard] PUNTOS curva:", curva.point_count)
	for i in range(curva.point_count):
		print("[MapBoard] Punto ", i, ": ", curva.get_point_position(i))
