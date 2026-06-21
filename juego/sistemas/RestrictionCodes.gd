class_name RestrictionCodes
extends RefCounted

# Mapeo entre track_key del juego (Godot) y códigos de restricción del backend.


const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const CODE_CELIAQUIA := "CELIAQUIA"
const CODE_VEG := "VEG"
const CODE_VYG := "VYG"
const CODE_KETO := "KETO"

const TRACK_TO_CODE := {
	GameTrackCatalog.TRACK_CELIAQUIA: CODE_CELIAQUIA,
	GameTrackCatalog.TRACK_VEGANISMO: CODE_VEG,
	GameTrackCatalog.TRACK_VEGANISMO_CELIAQUIA: CODE_VYG,
	GameTrackCatalog.TRACK_CETOGENICA: CODE_KETO,
	"keto": CODE_KETO,
}

const CODE_TO_TRACK := {
	CODE_CELIAQUIA: GameTrackCatalog.TRACK_CELIAQUIA,
	CODE_VEG: GameTrackCatalog.TRACK_VEGANISMO,
	CODE_VYG: GameTrackCatalog.TRACK_VEGANISMO_CELIAQUIA,
	CODE_KETO: GameTrackCatalog.TRACK_CETOGENICA,
}


static func normalizar_desde_juego(valor: String) -> String:
	var clean := valor.strip_edges()
	if clean.is_empty():
		return ""

	var lower := clean.to_lower()
	if TRACK_TO_CODE.has(lower):
		return TRACK_TO_CODE[lower]

	var upper := clean.to_upper()
	if CODE_TO_TRACK.has(upper):
		return upper

	return upper


static func track_desde_codigo(code: String) -> String:
	var upper := code.strip_edges().to_upper()
	if CODE_TO_TRACK.has(upper):
		return CODE_TO_TRACK[upper]
	return code.strip_edges().to_lower()


static func scope_leaderboard_desde_juego(valor: String) -> String:
	var code := normalizar_desde_juego(valor)
	if CODE_TO_TRACK.has(code):
		return LeaderboardScopeCatalog.scope_restriccion(code)
	return LeaderboardApi.SCOPE_XP_GLOBAL


static func etiqueta_scope(scope: String) -> String:
	if scope == LeaderboardApi.SCOPE_XP_GLOBAL:
		return "XP Global"
	if scope == LeaderboardApi.SCOPE_RACHA:
		return "Mejor Racha"
	if LeaderboardScopeCatalog.es_scope_restriccion(scope):
		var code := scope.substr("restriction:".length())
		return LeaderboardScopeCatalog.etiqueta_restriccion(code)
	return scope
