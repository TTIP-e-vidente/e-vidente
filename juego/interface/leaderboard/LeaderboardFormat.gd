class_name LeaderboardFormat
extends RefCounted

# Helpers de formato compartidos entre filas, card propia y meta del leaderboard.


static func es_scope_racha(scope: String) -> bool:
	return scope == "streak" or scope == LeaderboardApi.SCOPE_RACHA


static func formatear_score(score: int, scope: String) -> String:
	if es_scope_racha(scope):
		return formatear_racha(score)
	return formatear_xp(score)


static func es_scope_xp(scope: String) -> bool:
	return scope == "global_xp" or scope == LeaderboardApi.SCOPE_XP_GLOBAL or LeaderboardScopeCatalog.es_scope_restriccion(scope)


static func formatear_xp(score: int) -> String:
	if score >= 1_000_000:
		return "%.1fM XP" % (float(score) / 1_000_000)
	if score >= 1_000:
		return "%.1fK XP" % (float(score) / 1_000)
	return "%d XP" % score


static func formatear_racha(dias: int) -> String:
	if dias == 1:
		return "1 día"
	return "%d días" % dias


static func texto_posicion(posicion: int) -> String:
	if posicion <= 0:
		return "—"
	return "#%d" % posicion


static func color_posicion(posicion: int, es_propio: bool = false) -> Color:
	if es_propio:
		return Color.WHITE
	match posicion:
		1: return MiPaleta.ORO_CLARO
		2: return Color("#C0C0C0")
		3: return Color("#CD7F32")
		_: return Color(0.14, 0.13, 0.09, 1)


static func parsear_computed_at(valor: Variant) -> float:
	if valor == null:
		return -1.0
	if valor is float or valor is int:
		return float(valor)
	if valor is String:
		var iso := (valor as String).strip_edges()
		if iso.is_empty():
			return -1.0
		# Godot 4.0.x: ISO sin "Z" ni fracción decimal; formato "YYYY-MM-DDTHH:MM:SS".
		var normalizado := iso.replace("Z", "")
		if " " in normalizado and "T" not in normalizado:
			normalizado = normalizado.replace(" ", "T")
		if "." in normalizado:
			normalizado = normalizado.split(".")[0]

		var datetime_dict := Time.get_datetime_dict_from_datetime_string(normalizado, false)
		if datetime_dict.is_empty():
			return -1.0
		return float(Time.get_unix_time_from_datetime_dict(datetime_dict))
	return -1.0


static func texto_actualizacion(datos: Dictionary) -> String:
	if bool(datos.get("is_live_fallback", false)):
		return "datos en vivo"
	var ts := parsear_computed_at(datos.get("computed_at", null))
	if ts < 0:
		return ""
	var diff := Time.get_unix_time_from_system() - ts
	if diff < 60:
		return "actualizado hace un momento"
	if diff < 3600:
		return "actualizado hace %d min" % int(diff / 60)
	if diff < 86400:
		return "actualizado hace %d h" % int(diff / 3600)
	return "actualizado hace %d días" % int(diff / 86400)


static func texto_meta(datos: Dictionary) -> String:
	var partes: Array[String] = []
	var total := int(datos.get("total", 0))
	if total > 0:
		partes.append("%d jugadores" % total)
	var freshness := texto_actualizacion(datos)
	if not freshness.is_empty():
		partes.append(freshness)
	return " · ".join(partes)
