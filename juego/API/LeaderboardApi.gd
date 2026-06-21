class_name LeaderboardApi
extends RefCounted

# Cliente estático para comunicarse con el API del leaderboard.
#
# Delega todas las llamadas HTTP a BackendSession, que maneja
# el token de autenticación y el cliente HTTP.
# Todos los métodos son estáticos: no hay que instanciar esta clase.


# ── Constantes ─────────────────────────────────────────────────────────────────

const SCOPE_XP_GLOBAL := "global_xp"
const SCOPE_RACHA      := "streak"
const LIMITE_DEFAULT   := 50


# ── Lectura del leaderboard ────────────────────────────────────────────────────

# Pide el leaderboard de un scope al servidor.
# Si include_self=true y el usuario está logueado, el servidor también incluye
# la posición propia aunque no esté en el top.
static func obtener_leaderboard(
	scope: String = SCOPE_XP_GLOBAL,
	limite: int = LIMITE_DEFAULT,
	desplazamiento: int = 0,
	incluir_propio: bool = false
) -> Dictionary:
	return await BackendSession.obtener_leaderboard_online(
		scope,
		limite,
		desplazamiento,
		incluir_propio and AuthApi.esta_logueado()
	)


# Pide la posición propia del jugador logueado en todos los scopes.
static func obtener_mi_posicion() -> Dictionary:
	if not AuthApi.esta_logueado():
		return {"ok": false, "error": "Sin sesión activa"}
	return await BackendSession.obtener_mi_posicion_leaderboard_online()


# Pide metadata del snapshot (útil para debugging o monitoreo).
static func obtener_meta() -> Dictionary:
	return await BackendSession.obtener_meta_leaderboard_online()


# Obtiene el contexto competitivo del jugador logueado.
# Retorna los datos de /leaderboard/me/summary:
#   { available, current, next, exp_to_next_rank, progress_to_next_rank, is_first_place }
static func obtener_resumen_competitivo() -> Dictionary:
	if not AuthApi.esta_logueado():
		return {"ok": false, "error": "Sin sesión activa"}
	return await BackendSession.obtener_resumen_ranking_online()


# ── Helpers para procesar respuestas ──────────────────────────────────────────

# Retorna true si la respuesta fue exitosa y tiene al menos una entrada.
static func tiene_datos(resultado: Dictionary) -> bool:
	if not resultado.get("ok", false):
		return false
	var datos: Variant = resultado.get("data", null)
	if not datos is Dictionary:
		return false
	var entradas: Variant = (datos as Dictionary).get("entries", null)
	return entradas is Array and (entradas as Array).size() > 0


# Extrae el array de entradas del resultado, o retorna [] si falló.
static func extraer_entradas(resultado: Dictionary) -> Array:
	if not resultado.get("ok", false):
		return []
	var datos: Variant = resultado.get("data", null)
	if not datos is Dictionary:
		return []
	var entradas: Variant = (datos as Dictionary).get("entries", null)
	return entradas as Array if entradas is Array else []


# Extrae la posición propia del resultado, o retorna {} si no está disponible.
static func extraer_posicion_propia(resultado: Dictionary) -> Dictionary:
	if not resultado.get("ok", false):
		return {}
	var datos: Variant = resultado.get("data", null)
	if not datos is Dictionary:
		return {}
	var posicion: Variant = (datos as Dictionary).get("own_position", null)
	return posicion as Dictionary if posicion is Dictionary else {}


# Extrae el mensaje de error del resultado en formato legible para el usuario.
static func mensaje_error(resultado: Dictionary, fallback: String = "") -> String:
	var error_raw: Variant = resultado.get("error", "")
	if error_raw is String and not (error_raw as String).is_empty():
		return error_raw as String
	return fallback if not fallback.is_empty() \
		else "No se pudo cargar el leaderboard. Intentá más tarde."
