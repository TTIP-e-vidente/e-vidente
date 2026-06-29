class_name LeaderboardMiniList
extends VBoxContainer

# Lista compacta de entradas del ranking (top N o contexto cercano).


const ROW_SCENE := preload("res://interface/leaderboard/LeaderboardMiniRow.tscn")


@export var max_filas: int = 5
@export var animar_fila_propia: bool = true
@export var tema_claro: bool = false


func _ready() -> void:
	if not LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.connect(_al_avatar_cargado)


func _exit_tree() -> void:
	if LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.disconnect(_al_avatar_cargado)


func limpiar() -> void:
	for hijo in get_children():
		hijo.queue_free()


func poblar_desde_nearby(resumen: Dictionary, id_propio: String, scope: String = "") -> bool:
	var nearby: Variant = resumen.get("nearby_entries", [])
	if not nearby is Array or (nearby as Array).is_empty():
		return false

	var entradas := LeaderboardFormat.filtrar_entradas_validas(nearby as Array)
	if entradas.is_empty():
		return false

	limpiar()
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = str(resumen.get("scope", "global_xp"))

	var puesto_propio := 0
	var current: Variant = resumen.get("current", null)
	if current is Dictionary:
		puesto_propio = int((current as Dictionary).get("rank", 0))

	_agregar_filas_desde_entradas(
		entradas,
		id_propio,
		scope_final,
		entradas.size(),
		puesto_propio
	)
	return true


func poblar(datos: Dictionary, id_propio: String = "", limite: int = -1) -> void:
	limpiar()
	var datos_prep := LeaderboardFormat.preparar_datos_listado(datos, id_propio)
	var entradas: Variant = datos_prep.get("entries", [])
	if not entradas is Array:
		return

	var maximo := limite if limite > 0 else max_filas
	_agregar_filas_desde_entradas(
		entradas as Array,
		id_propio,
		str(datos_prep.get("scope", "global_xp")),
		maximo,
		0
	)


func poblar_cercanos(
	datos: Dictionary,
	puesto_centro: int,
	id_propio: String = "",
	radio: int = 2
) -> void:
	limpiar()
	var scope := str(datos.get("scope", "global_xp"))
	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array:
		return

	var cercanas := LeaderboardFormat.entradas_cercanas(entradas as Array, puesto_centro, radio)
	if cercanas.is_empty():
		poblar(datos, id_propio, max_filas)
		return

	_agregar_filas_desde_entradas(cercanas, id_propio, scope, cercanas.size(), puesto_centro)


func poblar_contexto_post_partida(
	datos_leaderboard: Dictionary,
	resumen_competitivo: Dictionary,
	puesto_centro: int,
	id_propio: String = "",
	radio: int = 2
) -> void:
	limpiar()
	if poblar_desde_nearby(resumen_competitivo, id_propio, str(datos_leaderboard.get("scope", ""))):
		return

	if puesto_centro <= 0:
		poblar(datos_leaderboard, id_propio, max_filas)
		return

	var scope := str(datos_leaderboard.get("scope", resumen_competitivo.get("scope", "global_xp")))
	var entradas: Variant = datos_leaderboard.get("entries", [])
	var cercanas: Array = []
	if entradas is Array:
		cercanas = LeaderboardFormat.entradas_cercanas(entradas as Array, puesto_centro, radio)

	if not _incluye_usuario(cercanas, id_propio):
		var own: Variant = datos_leaderboard.get("own_position", null)
		if own is Dictionary:
			var own_dict := own as Dictionary
			if not _entrada_ya_listada(cercanas, own_dict):
				cercanas.append(own_dict)

		var desde_resumen := LeaderboardFormat.entradas_contexto_desde_resumen(resumen_competitivo)
		for entrada in desde_resumen:
			if entrada is Dictionary and not _entrada_ya_listada(cercanas, entrada as Dictionary):
				cercanas.append(entrada)
		cercanas = LeaderboardFormat.entradas_cercanas(cercanas, puesto_centro, radio)

	if cercanas.is_empty():
		poblar(datos_leaderboard, id_propio, max_filas)
		return

	_agregar_filas_desde_entradas(cercanas, id_propio, scope, cercanas.size(), puesto_centro)


func _agregar_filas_desde_entradas(
	entradas: Array,
	id_propio: String,
	scope: String,
	maximo: int,
	puesto_propio: int = 0
) -> void:
	var contador := 0
	var vistos_usuario: Dictionary = {}
	var vistos_puesto: Dictionary = {}
	for entrada in entradas:
		if contador >= maximo:
			break
		if not entrada is Dictionary:
			continue
		var entry := entrada as Dictionary
		if not LeaderboardFormat.entrada_es_valida(entry):
			continue
		var user_id := str(entry.get("user_id", "")).strip_edges()
		var rank := int(entry.get("rank", 0))
		if not user_id.is_empty() and vistos_usuario.has(user_id):
			continue
		if rank > 0 and vistos_puesto.has(rank):
			continue
		if not user_id.is_empty():
			vistos_usuario[user_id] = true
		if rank > 0:
			vistos_puesto[rank] = true
		var fila := ROW_SCENE.instantiate() as LeaderboardMiniRow
		if fila == null:
			continue
		fila.tema_claro = tema_claro
		var es_propio := _es_fila_propia(entry, id_propio, puesto_propio)
		fila.poblar(entry, es_propio, scope)
		add_child(fila)
		contador += 1

	if animar_fila_propia:
		call_deferred("_animar_fila_propia")


func _entrada_es_valida(entry: Dictionary) -> bool:
	return LeaderboardFormat.entrada_es_valida(entry)


func _es_fila_propia(entry: Dictionary, id_propio: String, puesto_propio: int) -> bool:
	if not id_propio.is_empty() and str(entry.get("user_id", "")) == id_propio:
		return true
	if puesto_propio > 0 and int(entry.get("rank", 0)) == puesto_propio:
		return true
	return false


func _incluye_usuario(entradas: Array, id_propio: String) -> bool:
	if id_propio.is_empty():
		return false
	for entrada in entradas:
		if entrada is Dictionary and str((entrada as Dictionary).get("user_id", "")) == id_propio:
			return true
	return false


func _entrada_ya_listada(entradas: Array, candidata: Dictionary) -> bool:
	var rank_c := int(candidata.get("rank", 0))
	var user_c := str(candidata.get("user_id", ""))
	for entrada in entradas:
		if not entrada is Dictionary:
			continue
		var e := entrada as Dictionary
		if int(e.get("rank", 0)) == rank_c:
			return true
		if not user_c.is_empty() and str(e.get("user_id", "")) == user_c:
			return true
	return false


func _al_avatar_cargado(user_id: String, _texture: Texture2D) -> void:
	for hijo in get_children():
		if hijo is LeaderboardMiniRow:
			(hijo as LeaderboardMiniRow).refrescar_avatar_si_coincide(user_id)


func _animar_fila_propia() -> void:
	for hijo in get_children():
		if hijo is LeaderboardMiniRow and (hijo as LeaderboardMiniRow).es_fila_propia():
			(hijo as LeaderboardMiniRow).animar_atencion()
			return
