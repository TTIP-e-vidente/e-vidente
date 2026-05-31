extends RefCounted
class_name MapNodePositionResolver


# Calcula posiciones para todos los nodos del mapa usando la curva activa.
static func calcular_posiciones_para_nodos(
	nodos: Array,
	curva: Curve2D,
	config: MapLayoutConfig = null
) -> Array[Vector2]:
	if curva == null or curva.get_baked_length() <= 0.0:
		return []
	var cantidad: int = 0
	for raw_nodo in nodos:
		if raw_nodo as MapNodeData != null:
			cantidad += 1
	if cantidad == 0:
		return []
	return MapPathLayout.calcular_posiciones_en_curva(curva, cantidad, config)


# Devuelve la posición del nodo: usa posicion_auto si está disponible, sino fallback.
static func obtener_posicion_para_nodo(
	_nodo: MapNodeData,
	posicion_auto: Vector2,
	tiene_auto: bool,
	posicion_fallback: Vector2
) -> Vector2:
	if tiene_auto:
		return posicion_auto
	return obtener_posicion_fallback(posicion_fallback)


# Posición base del .tscn cuando la curva no tiene datos suficientes.
static func obtener_posicion_fallback(posicion_base: Vector2) -> Vector2:
	return posicion_base


# Siempre true: el JSON ya no define coordenadas por nodo.
static func usar_posicion_automatica(_nodo: MapNodeData) -> bool:
	return true

