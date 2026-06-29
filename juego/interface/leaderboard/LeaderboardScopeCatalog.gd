class_name LeaderboardScopeCatalog
extends RefCounted

# Catálogo de scopes del leaderboard (UI + prefetch).

const GameTrackCatalogScript := preload("res://niveles/GameTrackCatalog.gd")

const CODE_TO_TRACK := {
	"CELIAQUIA": GameTrackCatalogScript.TRACK_CELIAQUIA,
	"VEG": GameTrackCatalogScript.TRACK_VEGANISMO,
	"VYG": GameTrackCatalogScript.TRACK_VEGANISMO_CELIAQUIA,
	"KETO": GameTrackCatalogScript.TRACK_CETOGENICA,
}

# Scopes con ranking activo en UI (drawer perfil + modal). El resto → "Próximamente".
const RESTRICCIONES_ACTIVAS := ["CELIAQUIA"]


static func scope_disponible(scope: String) -> bool:
	var limpio := scope.strip_edges()
	if limpio == LeaderboardApi.SCOPE_XP_GLOBAL or limpio == LeaderboardApi.SCOPE_RACHA:
		return true
	if not es_scope_restriccion(limpio):
		return false
	var code := limpio.trim_prefix("restriction:").strip_edges().to_upper()
	return RESTRICCIONES_ACTIVAS.has(code)


static func obtener_categorias() -> Array[Dictionary]:
	var categorias: Array[Dictionary] = [
		{"scope": LeaderboardApi.SCOPE_XP_GLOBAL, "etiqueta": "XP Global"},
		{"scope": LeaderboardApi.SCOPE_RACHA, "etiqueta": "Mejor Racha"},
	]
	for code in _codigos_restriccion():
		var etiqueta := etiqueta_restriccion(code)
		var entry := {
			"scope": scope_restriccion(code),
			"etiqueta": etiqueta,
		}
		if code.strip_edges().to_upper() == "VYG":
			entry["etiqueta_tab"] = "Veg + Celía"
		categorias.append(entry)
	for i in categorias.size():
		var scope := str(categorias[i].get("scope", ""))
		categorias[i]["disponible"] = scope_disponible(scope)
	return categorias


static func obtener_categorias_visibles() -> Array[Dictionary]:
	var visibles: Array[Dictionary] = []
	for categoria in obtener_categorias():
		if bool(categoria.get("disponible", false)):
			visibles.append(categoria)
	return visibles


static func obtener_scopes_visibles() -> Array[String]:
	var scopes: Array[String] = []
	for categoria in obtener_categorias_visibles():
		var scope := str(categoria.get("scope", "")).strip_edges()
		if not scope.is_empty():
			scopes.append(scope)
	return scopes


static func scope_restriccion(code: String) -> String:
	return "restriction:%s" % code.strip_edges().to_upper()


static func etiqueta_restriccion(code: String) -> String:
	var code_upper := code.strip_edges().to_upper()
	if CODE_TO_TRACK.has(code_upper):
		var track: String = CODE_TO_TRACK[code_upper]
		var etiqueta := GameTrackCatalogScript.obtener_etiqueta_pista(track, "")
		if not etiqueta.is_empty():
			return etiqueta
	match code_upper:
		"CELIAQUIA": return "Celiaquía"
		"VEG":       return "Veganismo"
		"VYG":       return "Veganismo + Celiaquía"
		"KETO":      return "Keto"
		_:           return code


static func es_scope_restriccion(scope: String) -> bool:
	return scope.begins_with("restriction:")


static func siguiente_scope(scope: String) -> String:
	var categorias := obtener_categorias_visibles()
	for i in categorias.size():
		if str(categorias[i].get("scope", "")) == scope:
			var next_idx := (i + 1) % categorias.size()
			return str(categorias[next_idx].get("scope", LeaderboardApi.SCOPE_XP_GLOBAL))
	return LeaderboardApi.SCOPE_XP_GLOBAL


static func _codigos_restriccion() -> Array[String]:
	return ["CELIAQUIA", "VEG", "VYG", "KETO"]
