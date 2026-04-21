extends Node2D

@onready var nodes_container: Node2D = $NodesContainer


func get_nodes_container() -> Node2D:
	return nodes_container


func get_authored_level_nodes() -> Array[Node2D]:
	var authored_nodes: Array[Node2D] = []
	for child in nodes_container.get_children():
		var map_node: Node2D = child as Node2D
		if map_node == null or not map_node.has_method("build_node_data"):
			continue
		authored_nodes.append(map_node)

	authored_nodes.sort_custom(Callable(self, "_sort_nodes_by_id"))
	return authored_nodes


func has_authored_level_nodes() -> bool:
	return not get_authored_level_nodes().is_empty()


func _sort_nodes_by_id(a: Node2D, b: Node2D) -> bool:
	return int(a.get("nivel_id")) < int(b.get("nivel_id"))