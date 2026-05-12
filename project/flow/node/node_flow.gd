extends RefCounted
class_name NodeFlow

# Recibe un nodo y expone sus modalidades disponibles.
# No renderiza UI. No abre minijuegos. No calcula EXP.

signal modalidad_seleccionada(node_id: String, mode_id: String)


func confirmar_modalidad(node_id: String, mode_id: String) -> void:
	if node_id.is_empty() or mode_id.is_empty():
		push_warning("NodeFlow: node_id o mode_id vacío al confirmar modalidad.")
		return
	modalidad_seleccionada.emit(node_id, mode_id)


static func obtener_modalidades_del_nodo(node_data: MapNodeData) -> Array[String]:
	if node_data == null or not node_data.is_valid():
		return []

	var modalidades: Array[String] = []
	for juego in node_data.games:
		var modo_del_juego: String = str(juego.get("mode", "")).strip_edges()
		if modo_del_juego.is_empty():
			modo_del_juego = node_data.mode.strip_edges()
		if not modo_del_juego.is_empty() and not modalidades.has(modo_del_juego):
			modalidades.append(modo_del_juego)

	# Algunos nodos legacy no declaran modo por juego; se usa el modo del nodo.
	if modalidades.is_empty() and not node_data.mode.is_empty():
		modalidades.append(node_data.mode.strip_edges())

	return modalidades
