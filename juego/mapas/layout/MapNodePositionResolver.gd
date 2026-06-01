class_name MapNodePositionResolver
extends RefCounted

# Resuelve las posiciones de N nodos: elige entre modo anchors y modo curve,
# busca la ruta con MapRouteRegistry y delega la matemática a MapPathLayout.
# Las posiciones devueltas están en espacio Contenido (igual que RutaCeliaquia1.position = ZERO).


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
