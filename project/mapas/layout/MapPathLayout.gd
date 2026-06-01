class_name MapPathLayout
extends RefCounted

# Calcula N posiciones sobre una Curve2D usando la configuración de layout.
# Modo "curve": distribucion uniforme por distancia recorrida (sample_baked).
# Modo "anchors": mapeo directo indice-nodo → indice-punto de la curva.
# Las posiciones devueltas estan en el espacio local del Path2D que contiene la curva.


static func calculate_positions(
	curve: Curve2D, count: int, config: MapLayoutConfig
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if curve == null or count <= 0:
		return positions

	var baked_length: float = curve.get_baked_length()
	if baked_length <= 0.0:
		return positions

	var t_start: float = minf(config.start_margin, baked_length)
	var t_end: float = maxf(baked_length - config.end_margin, t_start)

	for i in range(count):
		var normalized: float = float(i) / float(maxi(count - 1, 1))
		var t: float = lerpf(t_start, t_end, normalized)
		positions.append(curve.sample_baked(t))

	return positions


## Modo anchors: cada nodo i toma directamente curve.get_point_position(i).
## Requiere curva con al menos `cantidad_nodos` puntos.
## Si la curva tiene menos puntos que nodos, usa sample_baked como fallback seguro.
static func calcular_posiciones_por_anchors(
	curva: Curve2D,
	cantidad_nodos: int
) -> Array[Vector2]:
	var posiciones: Array[Vector2] = []

	if curva == null:
		return posiciones

	if cantidad_nodos <= 0:
		return posiciones

	if curva.point_count >= cantidad_nodos:
		for i in range(cantidad_nodos):
			posiciones.append(curva.get_point_position(i))
		return posiciones

	# Fallback: curva con menos puntos que nodos → sample_baked uniforme.
	push_warning(
		"MapPathLayout.anchors: curva tiene %d puntos pero se necesitan %d. " \
		% [curva.point_count, cantidad_nodos] \
		+ "Usando sample_baked como fallback."
	)
	var baked_length: float = curva.get_baked_length()
	if baked_length <= 0.0:
		return posiciones
	for i in range(cantidad_nodos):
		var normalized: float = float(i) / float(maxi(cantidad_nodos - 1, 1))
		posiciones.append(curva.sample_baked(normalized * baked_length))
	return posiciones
