extends Node2D

@onready var nodes_container: Node2D = $ScrollContainer/Contenido/NodesContainer


func get_nodes_container() -> Node2D:
	return nodes_container


func get_authored_level_nodes() -> Array[Node2D]:
	var configured_nodes: Array[Node2D] = []
	for child in nodes_container.get_children():
		var map_node: Node2D = child as Node2D
		if map_node == null:
			continue
		if not map_node.has_method("build_node_data"):
			continue
		configured_nodes.append(map_node)

	configured_nodes.sort_custom(Callable(self, "_sort_by_nivel_id"))
	return configured_nodes


func _sort_by_nivel_id(a: Node2D, b: Node2D) -> bool:
	return int(a.get("nivel_id")) < int(b.get("nivel_id"))