class_name MapRouteRegistry
extends RefCounted

const ROUTES_FOLDER := "Rutas"


static func buscar_ruta(nodes_container: Node, route_id: String) -> Path2D:
	if nodes_container == null or route_id.is_empty():
		return null
	var routes_root: Node = nodes_container.get_node_or_null(ROUTES_FOLDER)
	if routes_root == null:
		return null
	var candidate: Node = routes_root.get_node_or_null(route_id)
	if candidate is Path2D:
		return candidate as Path2D
	return null
