class_name MapNodePositionResolver
extends RefCounted

# Resuelve las posiciones de N nodos combinando MapRouteRegistry y MapPathLayout.
# Las posiciones devueltas están en el espacio local del Path2D (= espacio del contenedor
# padre si el Path2D está en el origen, que es el contrato documentado para este proyecto).


static func resolve(
	route_container: Node, config: MapLayoutConfig, count: int
) -> Array[Vector2]:
	if config == null or not config.is_valid():
		return []
	var route: Path2D = MapRouteRegistry.find_route(route_container, config.route_id)
	if route == null:
		push_warning(
			"MapNodePositionResolver: ruta no encontrada '%s'" % config.route_id
		)
		return []
	if route.curve == null:
		push_warning(
			"MapNodePositionResolver: la ruta '%s' no tiene curva" % config.route_id
		)
		return []
	if config.usa_modo_anchors():
		return MapPathLayout.calcular_posiciones_por_anchors(route.curve, count)
	return MapPathLayout.calculate_positions(route.curve, count, config)
