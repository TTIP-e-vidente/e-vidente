extends RefCounted
class_name MapRouteRegistry


## Busca un Path2D por nombre dentro del contenedor de nodos del mapa.
## Si no encuentra la ruta pedida, registra un warning y devuelve null.
## El contenedor es típicamente NodesContainer en MapBoard.tscn.
static func obtener_ruta(contenedor: Node, route_id: String) -> Path2D:
	if contenedor == null:
		push_warning("[MapRouteRegistry] contenedor es null al buscar route_id='%s'." % route_id)
		return null
	if route_id.is_empty():
		push_warning("[MapRouteRegistry] route_id vacío.")
		return null
	var nodo: Node = contenedor.get_node_or_null(NodePath(route_id))
	if nodo == null:
		push_warning(
			"[MapRouteRegistry] No se encontró Path2D '%s' en el contenedor. Fallback a tscn base."
			% route_id
		)
		return null
	var ruta: Path2D = nodo as Path2D
	if ruta == null:
		push_warning(
			"[MapRouteRegistry] Nodo '%s' existe pero no es Path2D. Fallback a tscn base."
			% route_id
		)
		return null
	if ruta.curve == null or ruta.curve.get_baked_length() <= 0.0:
		push_warning(
			"[MapRouteRegistry] Path2D '%s' no tiene curva o está vacía. Fallback a tscn base."
			% route_id
		)
		return null
	return ruta


## Devuelve la Curve2D de la ruta o null si no existe/está vacía.
static func obtener_curva(contenedor: Node, route_id: String) -> Curve2D:
	var ruta: Path2D = obtener_ruta(contenedor, route_id)
	if ruta == null:
		return null
	return ruta.curve
