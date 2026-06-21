extends Node

# Singleton (Autoload) que gestiona la carga del leaderboard.
#
# Centraliza toda la comunicación con el API del leaderboard.
# Incluye cache en memoria para evitar requests repetidos.
# Las escenas de UI se suscriben a las señales y reaccionan a los cambios.


# ── Señales ────────────────────────────────────────────────────────────────────

# Emitida cuando los datos de un scope se cargan correctamente.
signal leaderboard_cargado(scope: String, datos: Dictionary)

# Emitida cuando ocurre un error al cargar un scope.
signal leaderboard_fallido(scope: String, mensaje: String)

# Emitida cuando se carga la posición propia del jugador logueado.
signal posicion_propia_cargada(posiciones: Array)


# ── Constantes ─────────────────────────────────────────────────────────────────

# Segundos que un resultado en cache se considera "fresco" antes de re-pedir al API.
const SEGUNDOS_CACHE_VALIDO := 60.0

# Cuántas entradas pedimos por página al API.
const LIMITE_POR_PAGINA := 50


# ── Estado interno ─────────────────────────────────────────────────────────────

# Cache por scope: { "global_xp": { "datos": {...}, "timestamp": 1234 }, ... }
var _cache: Dictionary = {}

# Flags para evitar requests dobles mientras uno está en vuelo.
var _cargando_scope: Dictionary = {}

# Cache de posición propia y su timestamp.
var _cache_posicion_propia: Array = []
var _timestamp_posicion_propia: float = -1.0
var _cargando_posicion_propia: bool = false


# ── API pública ────────────────────────────────────────────────────────────────

# Carga el leaderboard de un scope dado.
# Si hay cache fresco, emite la señal inmediatamente sin ir al API.
# Si hay una solicitud en vuelo para ese scope, no lanza otra.
func cargar(scope: String = "global_xp", forzar: bool = false) -> void:
	if not forzar and _cache_esta_fresco(scope):
		leaderboard_cargado.emit(scope, _cache[scope]["datos"])
		return

	if _cargando_scope.get(scope, false):
		return

	_cargando_scope[scope] = true
	var resultado := await LeaderboardApi.obtener_leaderboard(
		scope,
		LIMITE_POR_PAGINA,
		0,
		AuthApi.esta_logueado()
	)
	_cargando_scope[scope] = false

	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		_cache[scope] = {
			"datos": datos as Dictionary if datos is Dictionary else {},
			"timestamp": Time.get_unix_time_from_system()
		}
		leaderboard_cargado.emit(scope, _cache[scope]["datos"])
	else:
		var mensaje := LeaderboardApi.mensaje_error(resultado)
		leaderboard_fallido.emit(scope, mensaje)


# Pide la siguiente página de resultados y la adjunta a la lista existente.
# Usa un scope especial "scope:mas" para diferenciarlo de una carga completa.
func cargar_mas(scope: String, desplazamiento: int) -> void:
	var resultado := await LeaderboardApi.obtener_leaderboard(
		scope, LIMITE_POR_PAGINA, desplazamiento, false
	)
	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		leaderboard_cargado.emit(scope + ":mas", datos as Dictionary if datos is Dictionary else {})
	else:
		leaderboard_fallido.emit(scope, LeaderboardApi.mensaje_error(resultado))


# Carga la posición propia del jugador en todos los scopes.
# Solo funciona si el jugador tiene sesión activa.
func cargar_posicion_propia(forzar: bool = false) -> void:
	if not AuthApi.esta_logueado():
		return

	if not forzar and _cache_posicion_propia_esta_fresco():
		posicion_propia_cargada.emit(_cache_posicion_propia)
		return

	if _cargando_posicion_propia:
		return

	_cargando_posicion_propia = true
	var resultado := await LeaderboardApi.obtener_mi_posicion()
	_cargando_posicion_propia = false

	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		var posiciones_raw: Variant = {} if not datos is Dictionary else (datos as Dictionary).get("positions", [])
		_cache_posicion_propia = posiciones_raw as Array if posiciones_raw is Array else []
		_timestamp_posicion_propia = Time.get_unix_time_from_system()
		posicion_propia_cargada.emit(_cache_posicion_propia)


# Borra el cache de un scope específico, o todo el cache si no se pasa scope.
func invalidar_cache(scope: String = "") -> void:
	if scope.is_empty():
		_cache.clear()
	else:
		_cache.erase(scope)


# Retorna los datos cacheados de un scope (o vacío si no hay cache fresco).
func obtener_desde_cache(scope: String) -> Dictionary:
	if _cache_esta_fresco(scope):
		return _cache[scope]["datos"]
	return {}


# Indica si hay un request activo para ese scope.
func esta_cargando(scope: String) -> bool:
	return _cargando_scope.get(scope, false)


# ── Internos ───────────────────────────────────────────────────────────────────

# Retorna true si el cache del scope existe y no venció.
func _cache_esta_fresco(scope: String) -> bool:
	if not _cache.has(scope):
		return false
	var antiguedad := Time.get_unix_time_from_system() - float(_cache[scope]["timestamp"])
	return antiguedad < SEGUNDOS_CACHE_VALIDO


# Retorna true si el cache de posición propia existe y no venció.
func _cache_posicion_propia_esta_fresco() -> bool:
	if _timestamp_posicion_propia < 0:
		return false
	var antiguedad := Time.get_unix_time_from_system() - _timestamp_posicion_propia
	return antiguedad < SEGUNDOS_CACHE_VALIDO
