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


static func obtener_categorias() -> Array[Dictionary]:
	var categorias: Array[Dictionary] = [
		{"scope": LeaderboardApi.SCOPE_XP_GLOBAL, "etiqueta": "XP Global"},
		{"scope": LeaderboardApi.SCOPE_RACHA, "etiqueta": "Mejor Racha"},
	]
	for code in _codigos_restriccion():
		categorias.append({
			"scope": scope_restriccion(code),
			"etiqueta": etiqueta_restriccion(code),
		})
	return categorias


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
	var categorias := obtener_categorias()
	for i in categorias.size():
		if str(categorias[i].get("scope", "")) == scope:
			var next_idx := (i + 1) % categorias.size()
			return str(categorias[next_idx].get("scope", LeaderboardApi.SCOPE_XP_GLOBAL))
	return LeaderboardApi.SCOPE_XP_GLOBAL


static func _codigos_restriccion() -> Array[String]:
	return ["CELIAQUIA", "VEG", "VYG", "KETO"]
