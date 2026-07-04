class_name LeaderboardFormat
extends RefCounted

# Helpers de formato compartidos entre filas, card propia y meta del leaderboard.


static func entero_desde_json(valor: Variant, por_defecto: int = 0) -> int:
	# El backend puede devolver null en rank/score si el jugador no está en la tabla.
	if valor == null:
		return por_defecto
	if valor is int:
		return valor as int
	if valor is float:
		return int(valor)
	if valor is String:
		var texto := (valor as String).strip_edges()
		if texto.is_empty():
			return por_defecto
		if texto.is_valid_int():
			return int(texto)
		return por_defecto
	if valor is bool:
		return 1 if valor else 0
	return por_defecto


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


static func id_usuario_entrada(entrada: Dictionary) -> String:
	var user_id: Variant = entrada.get("user_id", entrada.get("userId", ""))
	return str(user_id).strip_edges()


static func resolver_nombre_entrada(entrada: Dictionary) -> String:
	var display: Variant = entrada.get("display_name", entrada.get("displayName", null))
	if display is String:
		var texto_display := (display as String).strip_edges()
		if not texto_display.is_empty():
			return texto_display

	var nombre: Variant = entrada.get("nombre", entrada.get("name", null))
	var apellido: Variant = entrada.get(
		"apellido",
		entrada.get("last_name", entrada.get("surname", null))
	)
	var partes: PackedStringArray = PackedStringArray()
	if nombre is String and not (nombre as String).strip_edges().is_empty():
		partes.append((nombre as String).strip_edges())
	if apellido is String and not (apellido as String).strip_edges().is_empty():
		partes.append((apellido as String).strip_edges())
	if not partes.is_empty():
		return " ".join(partes)

	var username: Variant = entrada.get("username", "")
	if username is String:
		var texto_user := (username as String).strip_edges()
		if not texto_user.is_empty():
			return texto_user
	return "—"


static func entradas_cercanas(entradas: Array, puesto_centro: int, radio: int = 2) -> Array:
	if puesto_centro <= 0 or radio < 0:
		return []

	var min_rank := maxi(1, puesto_centro - radio)
	var max_rank := puesto_centro + radio
	var filtradas: Array = []

	for entrada in entradas:
		if not entrada is Dictionary:
			continue
		var rank := int((entrada as Dictionary).get("rank", 0))
		if rank >= min_rank and rank <= max_rank:
			filtradas.append(entrada)

	filtradas.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("rank", 0)) < int(b.get("rank", 0))
	)
	return filtradas


static func entrada_es_valida(entry: Dictionary) -> bool:
	var user_id := id_usuario_entrada(entry)
	if user_id.is_empty():
		return false
	var rank := entero_desde_json(entry.get("rank", 0))
	if rank <= 0:
		return false
	return entero_desde_json(entry.get("score", 0)) > 0


static func filtrar_entradas_validas(entradas: Array) -> Array:
	var salida: Array = []
	var vistos_usuario: Dictionary = {}

	for entrada in entradas:
		if not entrada is Dictionary:
			continue
		var entry := entrada as Dictionary
		if not entrada_es_valida(entry):
			continue
		var user_id := id_usuario_entrada(entry)
		# Dedupe SOLO por usuario. NO por puesto: el backend usa RANK(), que asigna
		# el mismo puesto a jugadores empatados (ver dedupeEntries en
		# leaderboard.repository.ts) — filtrar por puesto repetido escondía a todos
		# los empatados menos uno (ej. dos rachas empatadas en 1er puesto).
		if vistos_usuario.has(user_id):
			continue
		vistos_usuario[user_id] = true
		salida.append(entry)

	salida.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return entero_desde_json(a.get("rank", 0)) < entero_desde_json(b.get("rank", 0))
	)
	return salida


static func preparar_datos_listado(datos: Dictionary, id_propio: String = "") -> Dictionary:
	var salida := datos.duplicate(true)
	var entradas_raw: Variant = salida.get("entries", [])
	if not entradas_raw is Array:
		return salida

	var filtradas := filtrar_entradas_validas(entradas_raw as Array)
	var own: Variant = salida.get("own_position", null)
	if own is Dictionary and entrada_es_valida(own as Dictionary):
		var own_dict := own as Dictionary
		var uid := id_usuario_entrada(own_dict)
		var incluye := false
		for entrada in filtradas:
			if entrada is Dictionary and id_usuario_entrada(entrada as Dictionary) == uid:
				incluye = true
				break
		if not incluye and (id_propio.is_empty() or uid == id_propio):
			filtradas.append(own_dict)
			filtradas = filtrar_entradas_validas(filtradas)

	salida["entries"] = filtradas
	return salida


static func entradas_contexto_desde_resumen(resumen: Dictionary) -> Array:
	var salida: Array = []
	var current: Variant = resumen.get("current", null)
	if current is Dictionary:
		salida.append(current)
	var siguiente: Variant = resumen.get("next", null)
	if siguiente is Dictionary:
		var rank_sig := int((siguiente as Dictionary).get("rank", 0))
		var rank_actual := int((current as Dictionary).get("rank", 0)) if current is Dictionary else 0
		if rank_sig > 0 and rank_sig != rank_actual:
			salida.append(siguiente)

	if current is Dictionary:
		var puesto := int((current as Dictionary).get("rank", 0))
		return entradas_cercanas(salida, puesto, 2)
	return salida


static func color_posicion(posicion: int, es_propio: bool = false) -> Color:
	if es_propio:
		return Color.WHITE
	match posicion:
		1: return MiPaleta.ORO_CLARO
		2: return Color("#C0C0C0")
		3: return Color("#CD7F32")
		_: return Color(0.14, 0.13, 0.09, 1)


# Colores legibles sobre tarjetas claras del drawer/perfil.
static func color_posicion_tarjeta_clara(posicion: int) -> Color:
	if posicion <= 0:
		return Color(0.278, 0.251, 0.184, 0.45)
	match posicion:
		1: return MiPaleta.ORO_CLARO
		2: return Color("#C0C0C0")
		3: return Color("#CD7F32")
		_: return Color(0.25882354, 0.47058824, 0.36862746, 1)


static func color_texto_secundario_tarjeta() -> Color:
	return Color(0.278, 0.251, 0.184, 0.72)


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
	var rango := texto_rango_pagina(datos)
	if not rango.is_empty():
		partes.append(rango)
	var freshness := texto_actualizacion(datos)
	if not freshness.is_empty():
		partes.append(freshness)
	return " · ".join(partes)


static func texto_rango_pagina(datos: Dictionary) -> String:
	var paginacion: Variant = datos.get("pagination", {})
	if not paginacion is Dictionary:
		return ""
	var offset := int((paginacion as Dictionary).get("offset", 0))
	if offset <= 0:
		return ""

	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array or (entradas as Array).is_empty():
		return "Página desde puesto %d" % (offset + 1)

	var primera: Dictionary = (entradas as Array)[0] as Dictionary
	var ultima: Dictionary = (entradas as Array)[(entradas as Array).size() - 1] as Dictionary
	var rank_min := int(primera.get("rank", offset + 1))
	var rank_max := int(ultima.get("rank", rank_min))
	if rank_min == rank_max:
		return "Mostrando %s" % texto_posicion(rank_min)
	return "Mostrando %s – %s" % [texto_posicion(rank_min), texto_posicion(rank_max)]


static func mensaje_sin_ranking(scope: String) -> String:
	if not LeaderboardScopeCatalog.scope_disponible(scope):
		return mensaje_proximamente()
	if es_scope_racha(scope):
		return "Sin racha activa"
	if LeaderboardScopeCatalog.es_scope_restriccion(scope):
		return "Sin partidas"
	return "Sin datos"


static func mensaje_proximamente() -> String:
	return "Próximamente"


static func mensaje_scope_sin_progreso(scope: String, etiqueta: String = "") -> String:
	if not LeaderboardScopeCatalog.scope_disponible(scope):
		return "Este ranking estará disponible próximamente."
	var nombre := etiqueta.strip_edges()
	if nombre.is_empty():
		nombre = RestrictionCodes.etiqueta_scope(scope)
	if es_scope_racha(scope):
		return "Todavía no tenés racha activa en el ranking."
	if LeaderboardScopeCatalog.es_scope_restriccion(scope):
		return "Todavía no aparecés en %s. Jugá una partida para sumarte." % nombre
	return "Todavía no aparecés en el ranking de %s." % nombre


static func texto_tarjeta_modo_invitado() -> String:
	return "Modo invitado · solo lectura"


static func mensaje_progreso_no_suma() -> String:
	return "Podés ver el ranking. Tu progreso no suma puntos hasta iniciar sesión."


static func hint_meta_modo_invitado() -> String:
	return "Modo invitado · sin puntos"


static func mensaje_ranking_vacio_invitado() -> String:
	return "Cuando haya jugadores registrados vas a verlos acá. Iniciá sesión para sumar puntos."


static func titulo_ranking_post_partida() -> String:
	if AuthApi.esta_logueado():
		return "Tu posición"
	return "Ranking"


static func subtitulo_ranking_post_partida() -> String:
	if AuthApi.esta_logueado():
		return "Tu puesto después de esta partida."
	return ""


static func texto_no_volver_a_mostrar_ranking() -> String:
	return "Omitir ranking la próxima vez"


static func texto_preferencia_omitir_ranking_perfil() -> String:
	return "Omitir ranking después de cada partida"


static func hint_preferencia_omitir_ranking_perfil() -> String:
	return "Podés cambiarlo acá o al terminar una partida."


static func texto_ver_ranking() -> String:
	return "Ver ranking"


static func texto_saltar_ranking() -> String:
	return "Continuar al mapa"


static func texto_ver_ranking_esta_vez() -> String:
	return "Ver ranking esta vez"


static func texto_continuar_dashboard() -> String:
	return "Continuar"


static func texto_iniciar_sesion_para_competir() -> String:
	return "Iniciá sesión"


## Nombre del rival a superar para subir de puesto, usado tanto en la card de
## perfil (ProgresoPuestoCard) como en la barra de posición propia del listado
## completo (OwnPositionCard).
static func nombre_rival(siguiente: Variant) -> String:
	if not siguiente is Dictionary:
		return "el jugador anterior"
	var sig := siguiente as Dictionary
	var nombre := resolver_nombre_entrada(sig)
	if nombre != "—":
		return nombre
	var puesto := entero_desde_json(sig.get("rank", 0))
	return "puesto #%d" % puesto if puesto > 0 else "el jugador anterior"


## Texto "faltan X para superar a Y" / "¡Primero en Z!" compartido entre las
## distintas cards que muestran el progreso competitivo hacia el próximo puesto.
static func texto_progreso_siguiente_puesto(
	datos: Dictionary,
	scope: String,
	etiqueta_scope: String
) -> String:
	if bool(datos.get("is_first_place", false)):
		return "¡Primero en %s!" % etiqueta_scope
	var exp_faltante := entero_desde_json(datos.get("exp_to_next_rank", 0))
	if exp_faltante <= 0:
		return ""
	var faltante := formatear_score(exp_faltante, scope)
	var rival := nombre_rival(datos.get("next", {}))
	return "Faltan %s para superar a %s" % [faltante, rival]
