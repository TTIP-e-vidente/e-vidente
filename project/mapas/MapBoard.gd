extends Node2D

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var nodes_container: Node2D = $ScrollContainer/Contenido/NodesContainer


func get_nodes_container() -> Node2D:
	return nodes_container


func get_scroll_vertical_value() -> int:
	if scroll_container == null:
		return 0
	return int(scroll_container.scroll_vertical)


func set_scroll_vertical_value(scroll_value: int) -> void:
	if scroll_container == null:
		return
	var max_scroll: int = int(scroll_container.get_v_scroll_bar().max_value)
	scroll_container.scroll_vertical = clampi(scroll_value, 0, max_scroll)


func get_runtime_map_nodes() -> Array[Node2D]:
	var ordered_map_nodes: Array[Node2D] = []
	for child in nodes_container.get_children():
		var map_node: Node2D = child as Node2D
		if not _is_runtime_map_node(map_node):
			continue
		ordered_map_nodes.append(map_node)

	ordered_map_nodes.sort_custom(Callable(self, "_sort_by_nivel_id"))
	return ordered_map_nodes


func _is_runtime_map_node(map_node: Node2D) -> bool:
	if map_node == null:
		return false
	return map_node.has_method("build_runtime_node_data")


func _sort_by_nivel_id(a: Node2D, b: Node2D) -> bool:
	return int(a.get("nivel_id")) < int(b.get("nivel_id"))
