class_name MapRouteRegistry
extends RefCounted

# Encuentra un Path2D por nombre dentro de un nodo contenedor.
# El contenedor debe ser el nodo padre directo de los Path2D de ruta.


static func find_route(container: Node, route_id: String) -> Path2D:
	if container == null or route_id.is_empty():
		return null
	var candidate: Node = container.get_node_or_null(route_id)
	if candidate is Path2D:
		return candidate as Path2D
	return null
