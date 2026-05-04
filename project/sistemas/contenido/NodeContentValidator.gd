extends RefCounted

const MODO_QUIZ_CHOICE := "quiz_choice"
const MODO_DRAG_DROP := "drag_drop"


static func validate(node_data: Dictionary) -> String:
	var base_error: String = validate_base_fields(node_data)
	if not base_error.is_empty():
		return base_error
	return validate_content_for_mode(node_data)


static func clean(node_data: Dictionary) -> Dictionary:
	var modo: String = str(node_data.get("mode", "")).strip_edges()
	var contenido: Dictionary = _leer_diccionario(node_data.get("content", {}))
	return {
		"id": str(node_data.get("id", "")).strip_edges(),
		"theme": str(node_data.get("theme", "")).strip_edges(),
		"title": str(node_data.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(node_data.get("difficulty", "")).strip_edges()),
		"mode": modo,
		"content": _limpiar_contenido(modo, contenido)
	}


static func validate_base_fields(datos_nodo: Dictionary) -> String:
	for campo in ["id", "theme", "title", "difficulty", "mode", "content"]:
		if not datos_nodo.has(campo):
			return "Falta el campo obligatorio: %s" % campo

	if str(datos_nodo.get("id", "")).strip_edges().is_empty():
		return "El campo id no puede estar vacio."
	if str(datos_nodo.get("theme", "")).strip_edges().is_empty():
		return "El campo theme no puede estar vacio."
	if str(datos_nodo.get("title", "")).strip_edges().is_empty():
		return "El campo title no puede estar vacio."
	if str(datos_nodo.get("difficulty", "")).strip_edges().is_empty():
		return "El campo difficulty no puede estar vacio."
	if not datos_nodo.get("content", {}) is Dictionary:
		return "El campo content debe ser un objeto."
	return ""


static func validate_content_for_mode(datos_nodo: Dictionary) -> String:
	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	var contenido: Dictionary = _leer_diccionario(datos_nodo.get("content", {}))
	match modo:
		MODO_QUIZ_CHOICE:
			return _validar_quiz(contenido)
		MODO_DRAG_DROP:
			return _validar_drag_drop(contenido)
		_:
			return "Modo no soportado: %s" % modo


static func validar_datos_nodo(datos_nodo: Dictionary) -> String:
	return validate_base_fields(datos_nodo)


static func validar_contenido_por_modo(datos_nodo: Dictionary) -> String:
	return validate_content_for_mode(datos_nodo)


static func limpiar_datos_nodo(datos_nodo: Dictionary) -> Dictionary:
	return clean(datos_nodo)


static func _validar_quiz(contenido: Dictionary) -> String:
	if str(contenido.get("question", "")).strip_edges().is_empty():
		return "Quiz: falta question."
	var respuesta_correcta: String = str(contenido.get("correct_answer", "")).strip_edges()
	if respuesta_correcta.is_empty():
		return "Quiz: falta correct_answer."

	var opciones_incorrectas: Variant = contenido.get("wrong_options", [])
	if not opciones_incorrectas is Array:
		return "Quiz: wrong_options debe ser una lista."
	var wrong_options: Array[String] = _limpiar_textos(opciones_incorrectas)
	if wrong_options.is_empty():
		return "Quiz: wrong_options debe tener al menos una opcion."
	if wrong_options.has(respuesta_correcta):
		return "Quiz: wrong_options no puede incluir correct_answer."
	if wrong_options.size() > 3:
		return "Quiz: no puede tener mas de 4 opciones totales."
	return ""


static func _validar_drag_drop(contenido: Dictionary) -> String:
	if str(contenido.get("instruction", "")).strip_edges().is_empty():
		return "DragDrop: falta instruction."

	var targets_crudos: Variant = contenido.get("targets", [])
	if not targets_crudos is Array:
		return "DragDrop: targets debe ser una lista."
	var targets: Array = targets_crudos as Array
	if targets.is_empty():
		return "DragDrop: debe tener al menos un target."
		
	var ids_targets: Array[String] = []
	for indice_target in range(targets.size()):
		if not targets[indice_target] is Dictionary:
			return "DragDrop: target %d debe ser un objeto." % (indice_target + 1)
		var target: Dictionary = targets[indice_target] as Dictionary
		var target_id: String = str(target.get("id", "")).strip_edges()
		if target_id.is_empty():
			return "DragDrop: target %d sin id." % (indice_target + 1)
		if ids_targets.has(target_id):
			return "DragDrop: target repetido (%s)." % target_id
		ids_targets.append(target_id)
		
		if str(target.get("label", "")).strip_edges().is_empty():
			return "DragDrop: target %d sin label." % (indice_target + 1)

	var items_crudos: Variant = contenido.get("items", [])
	if not items_crudos is Array:
		return "DragDrop: items debe ser una lista."
	var items: Array = items_crudos as Array
	if items.is_empty():
		return "DragDrop: debe tener al menos un item."
		
	var ids_items: Array[String] = []
	var hay_items_correctos: bool = false
	for indice_item in range(items.size()):
		if not items[indice_item] is Dictionary:
			return "DragDrop: item %d debe ser un objeto." % (indice_item + 1)
		var item: Dictionary = items[indice_item] as Dictionary
		var item_id: String = str(item.get("id", "")).strip_edges()
		if item_id.is_empty():
			return "DragDrop: item %d sin id." % (indice_item + 1)
		if ids_items.has(item_id):
			return "DragDrop: item repetido (%s)." % item_id
		ids_items.append(item_id)
		
		if str(item.get("label", "")).strip_edges().is_empty():
			return "DragDrop: item %d sin label." % (indice_item + 1)
		if not item.has("image"):
			return "DragDrop: item %d sin image." % (indice_item + 1)
		if not item.has("correct_target"):
			return "DragDrop: item %d sin correct_target." % (indice_item + 1)
			
		var correct_target: String = str(item.get("correct_target", "")).strip_edges()
		if not correct_target.is_empty():
			hay_items_correctos = true
			if not ids_targets.has(correct_target):
				return (
					"DragDrop: item %d apunta a target inexistente (%s)."
					% [(indice_item + 1), correct_target]
				)

	if not hay_items_correctos:
		return "DragDrop: no hay items correctos para completar la actividad."
	return ""


static func _limpiar_contenido(modo: String, contenido: Dictionary) -> Dictionary:
	match modo:
		MODO_QUIZ_CHOICE:
			return {
				"question": str(contenido.get("question", "")).strip_edges(),
				"correct_answer": str(contenido.get("correct_answer", "")).strip_edges(),
				"wrong_options": _limpiar_textos(contenido.get("wrong_options", [])),
				"visual_resource": str(contenido.get("visual_resource", "")).strip_edges()
			}
		MODO_DRAG_DROP:
			return {
				"instruction": str(contenido.get("instruction", "")).strip_edges(),
				"targets": _limpiar_targets(contenido.get("targets", [])),
				"items": _limpiar_items(contenido.get("items", [])),
				"success_message": str(contenido.get("success_message", "")).strip_edges(),
				"error_message": str(contenido.get("error_message", "")).strip_edges()
			}
	return contenido.duplicate(true)


static func _leer_diccionario(valor: Variant) -> Dictionary:
	if valor is Dictionary:
		return valor as Dictionary
	return {}


static func _limpiar_targets(targets_crudos: Variant) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not targets_crudos is Array:
		return targets

	for raw_target in targets_crudos:
		var target: Dictionary = _leer_diccionario(raw_target)
		if target.is_empty():
			continue
		targets.append({
			"id": str(target.get("id", "")).strip_edges(),
			"label": str(target.get("label", "")).strip_edges()
		})

	return targets


static func _limpiar_items(items_crudos: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not items_crudos is Array:
		return items

	for raw_item in items_crudos:
		var item: Dictionary = _leer_diccionario(raw_item)
		if item.is_empty():
			continue
		items.append({
			"id": str(item.get("id", "")).strip_edges(),
			"label": str(item.get("label", "")).strip_edges(),
			"image": str(item.get("image", "")).strip_edges(),
			"correct_target": str(item.get("correct_target", "")).strip_edges()
		})

	return items


static func _normalizar_dificultad(dificultad: String) -> String:
	var dificultad_limpia: String = dificultad.strip_edges().to_lower()
	match dificultad_limpia:
		"basica", "basic", "easy":
			return "easy"
		"media", "medium":
			return "medium"
		"avanzada", "advanced", "hard":
			return "hard"
		_:
			return dificultad_limpia


static func _limpiar_textos(valores: Variant) -> Array[String]:
	var textos: Array[String] = []
	if not valores is Array:
		return textos

	for raw_valor in valores:
		var valor: String = str(raw_valor).strip_edges()
		if valor.is_empty() or textos.has(valor):
			continue
		textos.append(valor)

	return textos
