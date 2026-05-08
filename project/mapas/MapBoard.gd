extends Node2D

signal node_selected(node_data: MapNodeData)

@onready var contenedor_scroll: ScrollContainer = $ScrollContainer
@onready var contenedor_nodos: Node2D = $ScrollContainer/Contenido/NodesContainer


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


func configurar_nodos(map_nodes: Array, node_states: Array[Dictionary]) -> void:
	var visual_nodes: Array[Node2D] = obtener_nodos_runtime_mapa()
	var visible_count: int = mini(visual_nodes.size(), map_nodes.size())

	if visual_nodes.size() != map_nodes.size():
		push_warning(
			"MapBoard: cantidad de nodos visuales (%d) distinta a nodos del JSON (%d)."
			% [visual_nodes.size(), map_nodes.size()]
		)

	for index in range(visible_count):
		var visual_node: Node2D = visual_nodes[index]
		var node_data: MapNodeData = map_nodes[index] as MapNodeData
		var node_state: Dictionary = _get_node_state(node_states, index)
		if node_data == null or not node_data.is_valid():
			visual_node.hide()
			continue

		visual_node.show()
		if node_data.has_map_position:
			visual_node.position = node_data.map_position
		if visual_node.has_method("configurar"):
			visual_node.configurar(node_data, node_state)
		var callback := Callable(self, "_on_visual_node_selected")
		var already_connected := visual_node.is_connected("selected", callback)
		if visual_node.has_signal("selected") and not already_connected:
			visual_node.connect("selected", callback)

	for index in range(visible_count, visual_nodes.size()):
		visual_nodes[index].hide()


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


func _get_node_state(node_states: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= node_states.size():
		return {}
	return node_states[index]


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
