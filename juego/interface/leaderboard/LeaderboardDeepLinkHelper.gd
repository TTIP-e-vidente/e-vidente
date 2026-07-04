class_name LeaderboardDeepLinkHelper
extends RefCounted

# Interpreta enlaces profundos (deep links) que llegan al juego desde un mail o la web.
#
# Formato esperado en la URL:
#   ?open=leaderboard&scope=global_xp
#   ?open=leaderboard&scope=restriction:CELIAQUIA
#
# También funciona si el sistema operativo pasa argumentos:
#   --open=leaderboard --scope=global_xp


const META_SCOPE_PENDIENTE := "leaderboard_deep_link_scope_pendiente"

const PARAMETRO_ACCION := "open"
const VALOR_ACCION_LEADERBOARD := "leaderboard"
const PARAMETRO_SCOPE := "scope"


static func registrar_solicitud_desde_arranque_del_sistema() -> void:
	var arbol := _obtener_arbol_de_escenas()
	if arbol == null or arbol.root == null:
		return

	for argumento in OS.get_cmdline_args():
		var parametros := _extraer_parametros_desde_texto(argumento)
		var scope := _scope_desde_parametros(parametros)
		if not scope.is_empty():
			arbol.root.set_meta(META_SCOPE_PENDIENTE, scope)
			return


static func abrir_leaderboard_si_hay_solicitud_pendiente(nodo_escena: Node) -> bool:
	if nodo_escena == null or nodo_escena.get_tree() == null:
		return false

	var arbol := nodo_escena.get_tree()
	var scope := _consumir_scope_pendiente(arbol.root)
	if scope.is_empty():
		return false

	LeaderboardOverlayHelper.abrir(arbol, scope)
	return true


static func _consumir_scope_pendiente(raiz: Window) -> String:
	if raiz == null or not raiz.has_meta(META_SCOPE_PENDIENTE):
		return ""

	var scope := str(raiz.get_meta(META_SCOPE_PENDIENTE, "")).strip_edges()
	raiz.remove_meta(META_SCOPE_PENDIENTE)
	return _normalizar_scope(scope)


static func _scope_desde_parametros(parametros: Dictionary) -> String:
	var accion := str(parametros.get(PARAMETRO_ACCION, "")).strip_edges().to_lower()
	if accion != VALOR_ACCION_LEADERBOARD:
		return ""
	return _normalizar_scope(str(parametros.get(PARAMETRO_SCOPE, "")))


static func _extraer_parametros_desde_texto(texto: String) -> Dictionary:
	var texto_limpio := texto.strip_edges()
	if texto_limpio.is_empty():
		return {}

	# Soporta: URL completa, query (?a=1&b=2) o argumento --clave=valor
	var parte_consulta := texto_limpio
	if texto_limpio.begins_with("--"):
		parte_consulta = texto_limpio.substr(2)
	elif "?" in texto_limpio:
		parte_consulta = texto_limpio.split("?", true, 1)[1]

	var parametros: Dictionary = {}
	for par in parte_consulta.split("&"):
		if par.is_empty():
			continue
		var partes := par.split("=", false, 1)
		if partes.size() < 2:
			continue
		var clave := partes[0].strip_edges().to_lower()
		var valor := partes[1].strip_edges().uri_decode()
		parametros[clave] = valor
	return parametros


static func _normalizar_scope(scope_raw: String) -> String:
	var scope_limpio := scope_raw.strip_edges()
	if scope_limpio.is_empty():
		return LeaderboardApi.SCOPE_XP_GLOBAL

	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		if str(categoria.get("scope", "")) == scope_limpio:
			return scope_limpio

	return LeaderboardApi.SCOPE_XP_GLOBAL


static func _obtener_arbol_de_escenas() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree if loop is SceneTree else null
