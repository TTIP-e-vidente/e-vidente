extends Node

# Singleton (Autoload) que gestiona la carga del leaderboard.
#
# Centraliza comunicación con el API, cache en memoria y evita requests duplicados.
# Las escenas de UI se suscriben a las señales y reaccionan a los cambios.


signal leaderboard_cargado(scope: String, datos: Dictionary)
signal leaderboard_fallido(scope: String, mensaje: String)
signal posicion_propia_cargada(posiciones: Array)
signal resumen_competitivo_cargado(datos: Dictionary)
signal resumen_competitivo_fallido(mensaje: String)


const SEGUNDOS_CACHE_VALIDO := 60.0
const LIMITE_POR_PAGINA := 50
const META_REFRESH_POST_PARTIDA := "leaderboard_refresh_scope_post_partida"


var _cache: Dictionary = {}
var _cargando_scope: Dictionary = {}

var _cache_posicion_propia: Array = []
var _timestamp_posicion_propia: float = -1.0
var _cargando_posicion_propia: bool = false

var _cache_resumen_por_scope: Dictionary = {}
var _cargando_resumen: bool = false


func cargar(scope: String = "global_xp", forzar: bool = false, offset: int = 0) -> void:
	offset = maxi(0, offset)
	var es_pagina := offset > 0
	var scope_evento := scope if not es_pagina else "%s:pagina" % scope
	var cache_key := scope if not es_pagina else "%s@o%d" % [scope, offset]

	if not forzar and _cache_esta_fresco(cache_key):
		leaderboard_cargado.emit(scope_evento, _cache[cache_key]["datos"])
		return

	if _cargando_scope.get(cache_key, false):
		return

	_cargando_scope[cache_key] = true
	var resultado := await LeaderboardApi.obtener_leaderboard(
		scope,
		LIMITE_POR_PAGINA,
		offset,
		AuthApi.esta_logueado()
	)
	_cargando_scope[cache_key] = false

	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		var datos_dict := datos as Dictionary if datos is Dictionary else {}
		_cache[cache_key] = {
			"datos": datos_dict,
			"timestamp": Time.get_unix_time_from_system()
		}
		if not es_pagina:
			_actualizar_cache_posicion_desde_leaderboard(scope, datos_dict)
		leaderboard_cargado.emit(scope_evento, datos_dict)
	else:
		var mensaje := LeaderboardApi.mensaje_error(resultado)
		leaderboard_fallido.emit(scope, mensaje)


func prefetch(scope: String) -> void:
	if _cache_esta_fresco(scope) or _cargando_scope.get(scope, false):
		return
	cargar(scope)


func prefetch_resumen_competitivo(scope: String = "global_xp") -> void:
	if not AuthApi.esta_logueado():
		return
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = "global_xp"
	if _cache_resumen_esta_fresco(scope_final) or _cargando_resumen:
		return
	cargar_resumen_competitivo(false, scope_final)


func cargar_mas(scope: String, desplazamiento: int) -> void:
	var resultado := await LeaderboardApi.obtener_leaderboard(
		scope, LIMITE_POR_PAGINA, desplazamiento, false
	)
	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", {})
		leaderboard_cargado.emit(scope + ":mas", datos as Dictionary if datos is Dictionary else {})
	else:
		leaderboard_fallido.emit(scope, LeaderboardApi.mensaje_error(resultado))


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


func cargar_resumen_competitivo(forzar: bool = false, scope: String = "global_xp") -> Dictionary:
	if not AuthApi.esta_logueado():
		return {"ok": false, "error": "Sin sesión activa"}

	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = "global_xp"

	if not forzar and _cache_resumen_esta_fresco(scope_final):
		var cacheado: Dictionary = _cache_resumen_por_scope[scope_final]["datos"]
		resumen_competitivo_cargado.emit(cacheado)
		return {"ok": true, "data": cacheado}

	if _cargando_resumen:
		return {"ok": false, "error": "Carga en curso"}

	_cargando_resumen = true
	var resultado := await LeaderboardApi.obtener_resumen_competitivo(scope_final)
	_cargando_resumen = false

	if resultado.get("ok", false):
		var datos: Variant = resultado.get("data", resultado)
		var datos_dict := datos as Dictionary if datos is Dictionary else {}
		_cache_resumen_por_scope[scope_final] = {
			"datos": datos_dict,
			"timestamp": Time.get_unix_time_from_system()
		}
		resumen_competitivo_cargado.emit(datos_dict)
	else:
		var mensaje := LeaderboardApi.mensaje_error(resultado)
		resumen_competitivo_fallido.emit(mensaje)

	return resultado


func invalidar_cache(scope: String = "") -> void:
	if scope.is_empty():
		_cache.clear()
		_cargando_scope.clear()
		_cache_posicion_propia.clear()
		_timestamp_posicion_propia = -1.0
		_cache_resumen_por_scope.clear()
	else:
		_cache.erase(scope)
		var prefijo := "%s@o" % scope
		for clave in _cache.keys():
			if clave == scope or str(clave).begins_with(prefijo):
				_cache.erase(clave)
		for clave in _cargando_scope.keys():
			if clave == scope or str(clave).begins_with(prefijo):
				_cargando_scope.erase(clave)
		_cache_resumen_por_scope.erase(scope)
		_remover_posicion_cache_para_scope(scope)


func obtener_desde_cache(scope: String) -> Dictionary:
	if _cache_esta_fresco(scope):
		return _cache[scope]["datos"]
	return {}


func obtener_resumen_desde_cache(scope: String = "global_xp") -> Dictionary:
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = "global_xp"
	if _cache_resumen_esta_fresco(scope_final):
		return _cache_resumen_por_scope[scope_final]["datos"]
	return {}


# Devuelve el puesto (#rank) guardado en cache para un scope.
# Si no hay datos o el jugador no aparece, retorna 0.
func obtener_puesto_desde_resumen_cache(scope: String = "global_xp") -> int:
	var resumen := obtener_resumen_desde_cache(scope)
	if resumen.is_empty():
		return 0
	if not bool(resumen.get("available", false)):
		return 0

	var datos_jugador: Variant = resumen.get("current", null)
	if not datos_jugador is Dictionary:
		return 0

	return int((datos_jugador as Dictionary).get("rank", 0))


func esta_cargando(scope: String) -> bool:
	return _cargando_scope.get(scope, false)


static func calcular_offset_para_rank(rank: int, limite: int = LIMITE_POR_PAGINA) -> int:
	if rank <= 1:
		return 0
	var pagina := int(floor(float(rank - 1) / float(limite)))
	return pagina * limite


func _actualizar_cache_posicion_desde_leaderboard(scope: String, datos: Dictionary) -> void:
	if not AuthApi.esta_logueado():
		return

	var own: Variant = datos.get("own_position", null)
	if own is Dictionary:
		var own_dict := own as Dictionary
		if own_dict.get("rank") != null:
			_merge_posicion_en_cache(scope, int(own_dict.get("rank", 0)), int(own_dict.get("score", 0)))
			return

	for entrada in datos.get("entries", []) as Array:
		if entrada is Dictionary:
			var entry := entrada as Dictionary
			var user_id := str(entry.get("user_id", ""))
			if user_id == _obtener_id_usuario_logueado():
				_merge_posicion_en_cache(scope, int(entry.get("rank", 0)), int(entry.get("score", 0)))
				return


func _merge_posicion_en_cache(scope: String, rank: int, score: int) -> void:
	var idx := -1
	for i in _cache_posicion_propia.size():
		var pos: Variant = _cache_posicion_propia[i]
		if pos is Dictionary and str((pos as Dictionary).get("scope", "")) == scope:
			idx = i
			break

	var nueva: Dictionary = {"scope": scope, "rank": rank, "score": score}
	if idx >= 0:
		_cache_posicion_propia[idx] = nueva
	else:
		_cache_posicion_propia.append(nueva)
	_timestamp_posicion_propia = Time.get_unix_time_from_system()


func _remover_posicion_cache_para_scope(scope: String) -> void:
	var filtradas: Array = []
	for pos in _cache_posicion_propia:
		if pos is Dictionary and str((pos as Dictionary).get("scope", "")) != scope:
			filtradas.append(pos)
	_cache_posicion_propia = filtradas


func _obtener_id_usuario_logueado() -> String:
	var datos_usuario := BackendSession.obtener_usuario_en_cache()
	return str(datos_usuario.get("id", ""))


func _cache_esta_fresco(scope: String) -> bool:
	if not _cache.has(scope):
		return false
	var antiguedad := Time.get_unix_time_from_system() - float(_cache[scope]["timestamp"])
	return antiguedad < SEGUNDOS_CACHE_VALIDO


func _cache_posicion_propia_esta_fresco() -> bool:
	if _timestamp_posicion_propia < 0:
		return false
	var antiguedad := Time.get_unix_time_from_system() - _timestamp_posicion_propia
	return antiguedad < SEGUNDOS_CACHE_VALIDO


func _cache_resumen_esta_fresco(scope: String) -> bool:
	if not _cache_resumen_por_scope.has(scope):
		return false
	var antiguedad := Time.get_unix_time_from_system() - float(_cache_resumen_por_scope[scope]["timestamp"])
	return antiguedad < SEGUNDOS_CACHE_VALIDO


func marcar_refresco_tras_partida(scope: String) -> void:
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.set_meta(META_REFRESH_POST_PARTIDA, scope_final)


func consumir_refresco_tras_partida() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	if not tree.root.has_meta(META_REFRESH_POST_PARTIDA):
		return ""
	var scope := str(tree.root.get_meta(META_REFRESH_POST_PARTIDA, "")).strip_edges()
	tree.root.remove_meta(META_REFRESH_POST_PARTIDA)
	return scope
