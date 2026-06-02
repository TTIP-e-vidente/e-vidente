extends RefCounted
class_name ValidadorDeContenidoDeNodo

# LEGACY_COMPAT: Usado por CargadorDeContenidoDeNodo.
# No agregar lógica nueva aquí; el contenido nuevo entra por NodeContentLoader.

# Valida y limpia el runtime que consumen los minijuegos.
# No carga archivos ni decide que activity se juega.

const MODO_QUIZ_CHOICE := "quiz_choice"
const MODO_DRAG_DROP := "drag_drop"
const MODO_VINCULACION_CONCEPTOS := "vinculacion_conceptos"


static func validar(datos_nodo: Dictionary) -> String:
	var base_error: String = _validar_campos_base(datos_nodo)
	if not base_error.is_empty():
		return base_error
	return _validar_contenido_por_modo(datos_nodo)


static func limpiar(datos_nodo: Dictionary) -> Dictionary:
	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	var contenido: Dictionary = _leer_diccionario(datos_nodo.get("content", {}))
	return {
		"id": str(datos_nodo.get("id", "")).strip_edges(),
		"theme": str(datos_nodo.get("theme", "")).strip_edges(),
		"title": str(datos_nodo.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(datos_nodo.get("difficulty", "")).strip_edges()),
		"mode": modo,
		"content": _limpiar_contenido(modo, contenido)
	}


static func _validar_campos_base(datos_nodo: Dictionary) -> String:
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


static func _validar_contenido_por_modo(datos_nodo: Dictionary) -> String:
	var modo: String = str(datos_nodo.get("mode", "")).strip_edges()
	var contenido: Dictionary = _leer_diccionario(datos_nodo.get("content", {}))
	match modo:
		MODO_QUIZ_CHOICE:
			return _validar_quiz(contenido)
		MODO_DRAG_DROP:
			return _validar_drag_drop(contenido)
		MODO_VINCULACION_CONCEPTOS:
			return _validar_vinculacion(contenido)
		_:
			return "Modo no soportado: %s" % modo


static func _validar_quiz(contenido: Dictionary) -> String:
	var preguntas_crudas: Variant = contenido.get("questions", contenido.get("preguntas", []))
	if preguntas_crudas is Array and not (preguntas_crudas as Array).is_empty():
		return _validar_quiz_con_multiples_preguntas(preguntas_crudas as Array)

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


static func _validar_quiz_con_multiples_preguntas(preguntas: Array) -> String:
	for indice in range(preguntas.size()):
		if not preguntas[indice] is Dictionary:
			return "Quiz: question %d debe ser un objeto." % (indice + 1)
		var pregunta: Dictionary = preguntas[indice] as Dictionary
		if str(pregunta.get("question", "")).strip_edges().is_empty():
			return "Quiz: question %d sin question." % (indice + 1)
		var respuesta_correcta: String = str(
			pregunta.get("correct_answer", "")
		).strip_edges()
		if respuesta_correcta.is_empty():
			return "Quiz: question %d sin correct_answer." % (indice + 1)
		var opciones_incorrectas: Variant = pregunta.get("wrong_options", [])
		if not opciones_incorrectas is Array:
			return "Quiz: question %d wrong_options debe ser una lista." % (indice + 1)
		var wrong_options: Array[String] = _limpiar_textos(opciones_incorrectas)
		if wrong_options.is_empty():
			return "Quiz: question %d necesita al menos una opcion incorrecta." % (indice + 1)
		if wrong_options.has(respuesta_correcta):
			return "Quiz: question %d repite correct_answer en wrong_options." % (indice + 1)
		if wrong_options.size() > 3:
			return "Quiz: question %d no puede tener mas de 4 opciones totales." % (indice + 1)
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

	var error_configuracion: String = _validar_configuracion_opcional_drag_drop(contenido)
	if not error_configuracion.is_empty():
		return error_configuracion
	return ""


static func _validar_configuracion_opcional_drag_drop(contenido: Dictionary) -> String:
	var elementos_maximos: Variant = contenido.get("elementos_maximos", null)
	if elementos_maximos != null:
		if not _es_entero_de_configuracion_drag_drop(elementos_maximos):
			return "DragDrop: elementos_maximos debe ser un entero."
		if int(elementos_maximos) < 1:
			return "DragDrop: elementos_maximos debe ser mayor o igual a 1."

	var distractores_maximos: Variant = contenido.get("distractores_maximos", null)
	if distractores_maximos != null:
		if not _es_entero_de_configuracion_drag_drop(distractores_maximos):
			return "DragDrop: distractores_maximos debe ser un entero."
		if int(distractores_maximos) < 0:
			return "DragDrop: distractores_maximos no puede ser negativo."
		if elementos_maximos != null and int(distractores_maximos) >= int(elementos_maximos):
			return "DragDrop: distractores_maximos debe dejar al menos un item correcto."

	var mostrar_ayuda_visual: Variant = contenido.get("mostrar_ayuda_visual", null)
	if mostrar_ayuda_visual != null and not mostrar_ayuda_visual is bool:
		return "DragDrop: mostrar_ayuda_visual debe ser booleano."

	return ""


static func _es_entero_de_configuracion_drag_drop(valor: Variant) -> bool:
	match typeof(valor):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_equal_approx(float(valor), round(float(valor)))
		_:
			return false


static func _limpiar_contenido(modo: String, contenido: Dictionary) -> Dictionary:
	match modo:
		MODO_QUIZ_CHOICE:
			return _limpiar_contenido_quiz(contenido)
		MODO_DRAG_DROP:
			return _limpiar_contenido_drag_drop(contenido)
		MODO_VINCULACION_CONCEPTOS:
			return {
				"instruccion": _leer_instruccion_vinculacion(contenido),
				"conceptos_izquierda": _limpiar_conceptos_vinculacion(
					_leer_lista_vinculacion(contenido, "conceptos_izquierda", "left_items")
				),
				"conceptos_derecha": _limpiar_conceptos_vinculacion(
					_leer_lista_vinculacion(contenido, "conceptos_derecha", "right_items")
				),
				"teaching_key": str(contenido.get("teaching_key", "")).strip_edges()
			}
	return contenido.duplicate(true)


static func _limpiar_contenido_quiz(contenido: Dictionary) -> Dictionary:
	var preguntas_crudas: Variant = contenido.get("questions", contenido.get("preguntas", []))
	if preguntas_crudas is Array and not (preguntas_crudas as Array).is_empty():
		return {"questions": _limpiar_preguntas_quiz(preguntas_crudas as Array)}
	return {
		"question": str(contenido.get("question", "")).strip_edges(),
		"correct_answer": str(contenido.get("correct_answer", "")).strip_edges(),
		"wrong_options": _limpiar_textos(contenido.get("wrong_options", [])),
		"visual_resource": str(contenido.get("visual_resource", "")).strip_edges()
	}


static func _limpiar_preguntas_quiz(preguntas_crudas: Array) -> Array[Dictionary]:
	var preguntas: Array[Dictionary] = []
	for raw_pregunta in preguntas_crudas:
		var pregunta: Dictionary = _leer_diccionario(raw_pregunta)
		if pregunta.is_empty():
			continue
		preguntas.append(
			{
				"id": str(pregunta.get("id", "")).strip_edges(),
				"question": str(pregunta.get("question", "")).strip_edges(),
				"correct_answer": str(pregunta.get("correct_answer", "")).strip_edges(),
				"wrong_options": _limpiar_textos(pregunta.get("wrong_options", [])),
				"visual_resource": str(pregunta.get("visual_resource", "")).strip_edges(),
				"explanation": str(pregunta.get("explanation", "")).strip_edges(),
			}
		)
	return preguntas


static func _limpiar_contenido_drag_drop(contenido: Dictionary) -> Dictionary:
	var contenido_limpio := {
		"teaching_key": str(contenido.get("teaching_key", "")).strip_edges(),
		"instruction": str(contenido.get("instruction", "")).strip_edges(),
		"targets": _limpiar_targets(contenido.get("targets", [])),
		"items": _limpiar_items(contenido.get("items", []))
	}
	if contenido.has("elementos_maximos"):
		contenido_limpio["elementos_maximos"] = int(contenido.get("elementos_maximos", 0))
	if contenido.has("distractores_maximos"):
		contenido_limpio["distractores_maximos"] = int(
			contenido.get("distractores_maximos", 0)
		)
	if contenido.has("mostrar_ayuda_visual"):
		contenido_limpio["mostrar_ayuda_visual"] = bool(
			contenido.get("mostrar_ayuda_visual", true)
		)
	return contenido_limpio


static func _validar_vinculacion(contenido: Dictionary) -> String:
	var instruccion: String = _leer_instruccion_vinculacion(contenido)
	if instruccion.is_empty():
		return "Vinculacion: falta instruccion."

	var conceptos_izquierda: Array[Dictionary] = _limpiar_conceptos_vinculacion(
		_leer_lista_vinculacion(contenido, "conceptos_izquierda", "left_items")
	)
	var conceptos_derecha: Array[Dictionary] = _limpiar_conceptos_vinculacion(
		_leer_lista_vinculacion(contenido, "conceptos_derecha", "right_items")
	)
	if conceptos_izquierda.size() < 2:
		return "Vinculacion: se requieren al menos dos conceptos a la izquierda."
	if conceptos_derecha.size() < 2:
		return "Vinculacion: se requieren al menos dos conceptos a la derecha."
	if conceptos_derecha.size() < conceptos_izquierda.size():
		return "Vinculacion: faltan conceptos a la derecha para todos los pares."

	var ids_izquierda: Dictionary = {}
	var ids_derecha: Dictionary = {}
	for indice in range(conceptos_izquierda.size()):
		var error_izquierda: String = _validar_concepto_vinculacion(
			conceptos_izquierda[indice],
			indice,
			"izquierda",
			ids_izquierda
		)
		if not error_izquierda.is_empty():
			return error_izquierda

	for indice in range(conceptos_derecha.size()):
		var error_derecha: String = _validar_concepto_vinculacion(
			conceptos_derecha[indice],
			indice,
			"derecha",
			ids_derecha
		)
		if not error_derecha.is_empty():
			return error_derecha

	for id_par in ids_izquierda.keys():
		if not ids_derecha.has(id_par):
			return "Vinculacion: falta el id_par %s en los conceptos de la derecha." % id_par

	return ""


static func _validar_concepto_vinculacion(
	concepto: Dictionary,
	indice: int,
	lado: String,
	ids_por_lado: Dictionary
) -> String:
	var etiqueta: String = "Vinculacion: concepto %d de %s" % [indice + 1, lado]
	var id_concepto: String = str(concepto.get("id", "")).strip_edges()
	if id_concepto.is_empty():
		return "%s sin id." % etiqueta
	var texto: String = str(concepto.get("texto", "")).strip_edges()
	if texto.is_empty():
		return "%s sin texto." % etiqueta
	var id_par: String = str(concepto.get("id_par", "")).strip_edges()
	if id_par.is_empty():
		return "%s sin id_par." % etiqueta
	if ids_por_lado.has(id_par):
		return "%s repite id_par (%s)." % [etiqueta, id_par]
	ids_por_lado[id_par] = true
	return ""


static func _leer_instruccion_vinculacion(contenido: Dictionary) -> String:
	return str(contenido.get("instruccion", contenido.get("instruction", ""))).strip_edges()


static func _leer_lista_vinculacion(
	contenido: Dictionary,
	clave_principal: String,
	clave_legacy: String
) -> Variant:
	return contenido.get(clave_principal, contenido.get(clave_legacy, []))


static func _limpiar_conceptos_vinculacion(conceptos_crudos: Variant) -> Array[Dictionary]:
	var conceptos: Array[Dictionary] = []
	if not conceptos_crudos is Array:
		return conceptos

	for raw_concepto in conceptos_crudos:
		var concepto: Dictionary = _leer_diccionario(raw_concepto)
		if concepto.is_empty():
			continue
		conceptos.append(
			{
				"id": str(concepto.get("id", "")).strip_edges(),
				"texto": str(concepto.get("texto", concepto.get("label", ""))).strip_edges(),
				"id_par": str(concepto.get("id_par", concepto.get("pair_id", ""))).strip_edges(),
			}
		)

	return conceptos


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
		if item.has("category"):
			items[items.size() - 1]["category"] = str(item.get("category", "")).strip_edges()
		if item.has("info_image"):
			items[items.size() - 1]["info_image"] = str(item.get("info_image", "")).strip_edges()

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
