extends VBoxContainer

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const TRACK_CARD_SCENE := preload("res://interface/container.tscn")


func _ready() -> void:
	reconstruir_tarjetas_pistas_desde_catalogo()


func reconstruir_tarjetas_pistas() -> void:
	reconstruir_tarjetas_pistas_desde_catalogo()


func reconstruir_tarjetas_pistas_desde_catalogo() -> void:
	_limpiar_tarjetas_pistas_existentes()
	for track_definition in GameTrackCatalog.obtener_definiciones_pista():
		_agregar_tarjeta_pista(track_definition)


func _limpiar_tarjetas_pistas_existentes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _agregar_tarjeta_pista(track_definition: Dictionary) -> void:
	var track_key := str(track_definition.get("key", "")).strip_edges()
	if track_key.is_empty():
		return
	var track_card := TRACK_CARD_SCENE.instantiate()
	if track_card == null:
		return
	track_card.name = "Track_%s" % track_key.replace("-", "_")
	add_child(track_card)
	if track_card is Control:
		(track_card as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if track_card.has_method("configurar"):
		track_card.call_deferred("configurar", track_definition)
