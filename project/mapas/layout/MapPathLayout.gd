extends RefCounted
class_name MapPathLayout


# Distribuye cantidad_nodos puntos sobre una polilínea (Array[Vector2]).
static func calcular_posiciones(
	puntos_guia: Array,
	cantidad_nodos: int
) -> Array[Vector2]:
	if puntos_guia.size() < 2 or cantidad_nodos <= 0:
		return []

	# Calcular longitud total de la ruta
	var segmentos: Array[float] = []
	var longitud_total: float = 0.0
	for i in range(puntos_guia.size() - 1):
		var d: float = (puntos_guia[i + 1] as Vector2).distance_to(puntos_guia[i] as Vector2)
		segmentos.append(d)
		longitud_total += d

	if longitud_total <= 0.0:
		return []

	var resultado: Array[Vector2] = []

	# Distribuir los nodos equidistantemente
	# El primer nodo va en t=0, el último en t=1 (inicio y fin de la ruta)
	for idx in range(cantidad_nodos):
		var t: float = float(idx) / float(max(cantidad_nodos - 1, 1))
		resultado.append(_interpolar_en_ruta(puntos_guia, segmentos, longitud_total, t))

	return resultado


static func _interpolar_en_ruta(
	puntos: Array,
	segmentos: Array[float],
	longitud_total: float,
	t: float
) -> Vector2:
	var dist_objetivo: float = clampf(t, 0.0, 1.0) * longitud_total
	var dist_acumulada: float = 0.0
	for i in range(segmentos.size()):
		var seg: float = segmentos[i]
		if dist_acumulada + seg >= dist_objetivo or i == segmentos.size() - 1:
			var t_local: float = 0.0
			if seg > 0.0:
				t_local = (dist_objetivo - dist_acumulada) / seg
			return (puntos[i] as Vector2).lerp(puntos[i + 1] as Vector2, clampf(t_local, 0.0, 1.0))
		dist_acumulada += seg
	return puntos[puntos.size() - 1] as Vector2


# Distribuye cantidad_nodos puntos sobre una Curve2D.
# Márgenes y modo de espaciado se leen del config (usa defaults si config es null).
static func calcular_posiciones_en_curva(
	curva: Curve2D,
	cantidad_nodos: int,
	config: MapLayoutConfig = null
) -> Array[Vector2]:
	if curva == null or cantidad_nodos <= 0:
		return []
	var largo: float = curva.get_baked_length()
	if largo <= 0.0:
		return []
	var inicio: float = 0.0
	var fin: float = largo
	if config != null:
		inicio = maxf(0.0, config.obtener_margen_inicio())
		fin = maxf(inicio, largo - config.obtener_margen_final())
	var rango: float = fin - inicio
	if rango <= 0.0:
		return []
	var modo: String = MapLayoutConfig.SPACING_EVEN if config == null else config.obtener_modo_espaciado()
	var factor: float = 1.0 if config == null else config.obtener_factor_espaciado()
	var ts: Array[float] = calcular_distancias_normalizadas(cantidad_nodos, modo, factor)
	var resultado: Array[Vector2] = []
	for t in ts:
		resultado.append(curva.sample_baked(inicio + t * rango))
	return resultado


# Calcula los t ∈ [0..1] para distribuir cantidad_nodos según modo y factor.
static func calcular_distancias_normalizadas(
	cantidad_nodos: int,
	modo: String = MapLayoutConfig.SPACING_EVEN,
	factor: float = 1.0
) -> Array[float]:
	if cantidad_nodos <= 0:
		return []
	if cantidad_nodos == 1:
		return [0.0]
	var factor_seguro: float = clampf(factor, 0.1, 5.0)
	var ts: Array[float] = []
	match modo:
		MapLayoutConfig.SPACING_SPACE_BETWEEN:
			for i in range(cantidad_nodos):
				ts.append(float(i) / float(cantidad_nodos - 1))
		MapLayoutConfig.SPACING_SPACE_AROUND:

			var paso: float = 1.0 / float(cantidad_nodos)
			for i in range(cantidad_nodos):
				ts.append(paso * 0.5 + paso * float(i))
		_:
			for i in range(cantidad_nodos):
				ts.append(float(i) / float(cantidad_nodos - 1))
	if absf(factor_seguro - 1.0) < 0.001:
		return ts
	# Aplicar factor: comprimir/expandir alrededor del centro 0.5
	var comprimidos: Array[float] = []
	for t in ts:
		var desplazado: float = (t - 0.5) * factor_seguro + 0.5
		comprimidos.append(clampf(desplazado, 0.0, 1.0))
	return comprimidos


# Devuelve el t para el índice i de N nodos.
static func calcular_distancia_para_indice(
	indice: int,
	cantidad_nodos: int,
	modo: String = MapLayoutConfig.SPACING_EVEN,
	factor: float = 1.0
) -> float:
	var ts: Array[float] = calcular_distancias_normalizadas(cantidad_nodos, modo, factor)
	if indice < 0 or indice >= ts.size():
		return 0.0
	return ts[indice]


# Legado: resuelve posición con prioridad manual > ruta > base.
static func resolver_posicion_nodo(
	indice: int,
	tiene_posicion_manual: bool,
	posicion_manual: Vector2,
	posiciones_de_ruta: Array[Vector2],
	posicion_base: Vector2
) -> Vector2:
	if tiene_posicion_manual:
		return posicion_manual
	if indice < posiciones_de_ruta.size():
		return posiciones_de_ruta[indice]
	return posicion_base
