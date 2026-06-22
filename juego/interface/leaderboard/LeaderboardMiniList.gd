class_name LeaderboardMiniList
extends VBoxContainer

# Lista compacta de entradas del ranking (top N o contexto cercano).


const ROW_SCENE := preload("res://interface/leaderboard/LeaderboardMiniRow.tscn")


@export var max_filas: int = 5


func limpiar() -> void:
	for hijo in get_children():
		hijo.queue_free()


func poblar(datos: Dictionary, id_propio: String = "", limite: int = -1) -> void:
	limpiar()
	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array:
		return

	var maximo := limite if limite > 0 else max_filas
	_agregar_filas_desde_entradas(entradas as Array, id_propio, str(datos.get("scope", "global_xp")), maximo)


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

	_agregar_filas_desde_entradas(cercanas, id_propio, scope, cercanas.size())


func poblar_contexto_post_partida(
	datos_leaderboard: Dictionary,
	resumen_competitivo: Dictionary,
	puesto_centro: int,
	id_propio: String = "",
	radio: int = 2
) -> void:
	limpiar()
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

	_agregar_filas_desde_entradas(cercanas, id_propio, scope, cercanas.size())


func _agregar_filas_desde_entradas(
	entradas: Array,
	id_propio: String,
	scope: String,
	maximo: int
) -> void:
	var contador := 0
	for entrada in entradas:
		if contador >= maximo:
			break
		if not entrada is Dictionary:
			continue
		var entry := entrada as Dictionary
		var fila := ROW_SCENE.instantiate() as LeaderboardMiniRow
		if fila == null:
			continue
		var es_propio := str(entry.get("user_id", "")) == id_propio and not id_propio.is_empty()
		fila.poblar(entry, es_propio, scope)
		add_child(fila)
		contador += 1


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
