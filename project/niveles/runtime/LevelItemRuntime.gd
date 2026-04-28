extends RefCounted

var _gestor


func _init(manager) -> void:
	_gestor = manager


func crear_elemento(
	elemento_nivel,
	instance_id: String,
	es_positivo: bool
):
	var instancia_elemento = elemento_nivel.escena.instantiate()
	if instancia_elemento == null:
		return null
	instancia_elemento.setup(elemento_nivel, _gestor.plato, es_positivo, instance_id)
	_gestor.add_child(instancia_elemento)
	_gestor.level_items.append(instancia_elemento)
	return instancia_elemento


func limpiar_elementos() -> void:
	for item in _gestor.level_items:
		if is_instance_valid(item):
			item.queue_free()
	_gestor.level_items.clear()
	if not is_instance_valid(_gestor.plato):
		return
	_gestor.plato.elementos.clear()
	_gestor.plato.cantAlimentosPos.clear()
	_gestor.plato.cantAlimentosNeg.clear()


func distribuir_elementos(recurso_nivel) -> void:
	var next_item_position: Vector2 = Vector2(230, 680)
	var total_items: int = recurso_nivel.cantidadNegativos + recurso_nivel.cantidadPositivos
	if total_items < 5:
		next_item_position = Vector2(420, 680)

	for item in _gestor.level_items:
		item.set_home_position(next_item_position)
		next_item_position.x += 120
