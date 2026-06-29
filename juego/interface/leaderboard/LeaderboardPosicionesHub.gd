class_name LeaderboardPosicionesHub
extends PanelContainer

# Hub "Tus rankings": una card por scope con la posición del jugador.


signal scope_presionado(scope: String)


const ESCENA_CARD := preload("res://interface/leaderboard/LeaderboardPosicionHubCard.tscn")


@onready var _grid: GridContainer = %GridCards


var _cards_por_scope: Dictionary = {}


func _ready() -> void:
	if not LeaderboardService.posicion_propia_cargada.is_connected(_al_posiciones_cargadas):
		LeaderboardService.posicion_propia_cargada.connect(_al_posiciones_cargadas)
	_construir_cards()


func _exit_tree() -> void:
	if LeaderboardService.posicion_propia_cargada.is_connected(_al_posiciones_cargadas):
		LeaderboardService.posicion_propia_cargada.disconnect(_al_posiciones_cargadas)


func cargar(forzar: bool = false) -> void:
	if not AuthApi.esta_logueado():
		visible = false
		return

	visible = true
	_marcar_todas_cargando()
	LeaderboardService.cargar_posicion_propia(forzar)


func _construir_cards() -> void:
	if not is_instance_valid(_grid):
		return

	for hijo in _grid.get_children():
		hijo.queue_free()
	_cards_por_scope.clear()

	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		var scope := str(categoria.get("scope", ""))
		var etiqueta := str(categoria.get("etiqueta", scope))
		if scope.is_empty():
			continue

		var card := ESCENA_CARD.instantiate() as LeaderboardPosicionHubCard
		_grid.add_child(card)
		card.configurar(etiqueta, scope, 0, 0)
		card.scope_presionado.connect(_al_card_presionada)
		_cards_por_scope[scope] = card


func _marcar_todas_cargando() -> void:
	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		var scope := str(categoria.get("scope", ""))
		var etiqueta := str(categoria.get("etiqueta", scope))
		if scope.is_empty() or not _cards_por_scope.has(scope):
			continue
		var card: LeaderboardPosicionHubCard = _cards_por_scope[scope]
		card.marcar_cargando(etiqueta, scope)


func _al_posiciones_cargadas(posiciones: Array) -> void:
	if not AuthApi.esta_logueado():
		visible = false
		return

	var mapa: Dictionary = {}
	for pos in posiciones:
		if pos is Dictionary:
			var scope := str((pos as Dictionary).get("scope", ""))
			if not scope.is_empty():
				mapa[scope] = pos

	var items_orden: Array[Dictionary] = []
	for categoria in LeaderboardScopeCatalog.obtener_categorias():
		var scope := str(categoria.get("scope", ""))
		var etiqueta := str(categoria.get("etiqueta", scope))
		if scope.is_empty() or not _cards_por_scope.has(scope):
			continue

		var card: LeaderboardPosicionHubCard = _cards_por_scope[scope]
		var rank := 0
		var score := 0
		if mapa.has(scope):
			var datos: Dictionary = mapa[scope]
			var etiqueta_api := str(datos.get("scope_label", "")).strip_edges()
			if not etiqueta_api.is_empty():
				etiqueta = etiqueta_api
			rank = LeaderboardFormat.entero_desde_json(datos.get("rank", 0))
			score = LeaderboardFormat.entero_desde_json(datos.get("score", 0))
		card.configurar(etiqueta, scope, rank, score)
		items_orden.append({"scope": scope, "card": card, "rank": rank})

	items_orden.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var rank_a := LeaderboardFormat.entero_desde_json(a.get("rank", 0))
			var rank_b := LeaderboardFormat.entero_desde_json(b.get("rank", 0))
			if rank_a <= 0:
				return false
			if rank_b <= 0:
				return true
			return rank_a < rank_b
	)

	var mejor_rank := 0
	var mejor_scope := ""
	for i in items_orden.size():
		var item: Dictionary = items_orden[i]
		var card: LeaderboardPosicionHubCard = item.get("card") as LeaderboardPosicionHubCard
		if is_instance_valid(_grid) and is_instance_valid(card):
			_grid.move_child(card, i)
		var rank := LeaderboardFormat.entero_desde_json(item.get("rank", 0))
		if rank > 0 and (mejor_rank <= 0 or rank < mejor_rank):
			mejor_rank = rank
			mejor_scope = str(item.get("scope", ""))

	for scope in _cards_por_scope:
		var card: LeaderboardPosicionHubCard = _cards_por_scope[scope]
		card.marcar_destacada(str(scope) == mejor_scope and mejor_rank > 0)


func _al_card_presionada(scope: String) -> void:
	scope_presionado.emit(scope)
