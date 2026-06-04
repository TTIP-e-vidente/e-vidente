class_name MapPathLayout
extends RefCounted


static func resolver(
		nodes_container: Node, config: MapLayoutConfig, node_count: int) -> Array[Vector2]:
	if config == null or not config.es_valido() or node_count <= 0:
		return []
	var route: Path2D = MapRouteRegistry.buscar_ruta(nodes_container, config.route_id)
	if route == null:
		push_warning("MapPathLayout: ruta no encontrada '%s'" % config.route_id)
		return []
	if route.curve == null:
		push_warning("MapPathLayout: ruta '%s' sin curva" % config.route_id)
		return []
	if config.es_modo_anchors():
		return calcular_por_anchors(route.curve, node_count)
	return calcular_por_curva(route.curve, node_count, config)


static func calcular_por_curva(
		curve: Curve2D, count: int, config: MapLayoutConfig) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if curve == null or count <= 0:
		return positions

	var baked_length: float = curve.get_baked_length()
	if baked_length <= 0.0:
		return positions

	var t_start: float = minf(config.start_margin, baked_length)
	var t_end: float = maxf(baked_length - config.end_margin, t_start)

	for i in range(count):
		var normalizado: float = float(i) / float(maxi(count - 1, 1))
		var t: float = lerpf(t_start, t_end, normalizado)
		positions.append(curve.sample_baked(t))

	return positions


static func calcular_por_anchors(curve: Curve2D, node_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if curve == null or node_count <= 0:
		return positions

	if curve.point_count >= node_count:
		for i in range(node_count):
			positions.append(curve.get_point_position(i))
		return positions

	push_warning(
		"MapPathLayout: curva con %d puntos, se necesitan %d. Usando sample_baked."
		% [curve.point_count, node_count]
	)
	var baked_length: float = curve.get_baked_length()
	if baked_length <= 0.0:
		return positions
	for i in range(node_count):
		var normalizado: float = float(i) / float(maxi(node_count - 1, 1))
		positions.append(curve.sample_baked(normalizado * baked_length))
	return positions


static func sincronizar_anchors_desde_nodos(
		nodes_container: Node,
		route_id: String,
		visual_nodes: Array) -> bool:
	var route: Path2D = MapRouteRegistry.buscar_ruta(nodes_container, route_id)
	if route == null or route.curve == null:
		return false
	var curve: Curve2D = route.curve
	curve.clear_points()
	for visual_node in visual_nodes:
		var nodo: Node2D = visual_node as Node2D
		if nodo == null:
			continue
		curve.add_point(nodo.position)
	return curve.point_count > 0
