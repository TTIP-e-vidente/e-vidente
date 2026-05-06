extends RefCounted


# Este archivo aisla TODA compatibilidad del flujo anterior al contenido oficial en
# res://contenido/nodos/. Si aparece una ruta vieja o un shape viejo, debe resolverse aca.
# El flujo nuevo no deberia agregar dependencias nuevas a res://niveles/nodos/ ni
# a res://preguntas/json_nodos/ fuera de este adaptador.

const MODO_QUIZ_CHOICE := "quiz_choice"
const MODO_DRAG_DROP := "drag_drop"
const DIRECTORIO_NODOS_ACTUAL := "res://contenido/nodos/"

# Compatibilidad temporal para contenido anterior a la migracion a
# res://contenido/nodos/. Mantener aislado en este archivo.
const DIRECTORIO_NODOS_ANTERIOR := "res://niveles/nodos/"
const DIRECTORIO_NODOS_LEGACY := "res://preguntas/json_nodos/"
const DIRECTORIO_PROYECTO_NODOS_ACTUAL := "project/contenido/nodos/"
const DIRECTORIO_PROYECTO_NODOS_ANTERIOR := "project/niveles/nodos/"
const DIRECTORIO_PROYECTO_NODOS_LEGACY := "project/preguntas/json_nodos/"


static func resolver_ruta_json(json_path: String) -> String:
	var clean_path: String = json_path.strip_edges()
	if clean_path.is_empty():
		return ""
	if FileAccess.file_exists(clean_path):
		return clean_path

	var res_path: String = _normalizar_ruta_proyecto(clean_path)
	if FileAccess.file_exists(res_path):
		return res_path

	var legacy_path: String = _resolver_ruta_legacy(res_path)
	if not legacy_path.is_empty():
		if _debe_advertir_ruta_legacy(clean_path, legacy_path):
			push_warning(
				"NodeContentLoader: ruta legacy detectada. Usa %s en lugar de %s."
				% [legacy_path, clean_path]
			)
		return legacy_path

	return res_path


static func normalizar_datos_nodo(raw_data: Dictionary) -> Dictionary:
	if _es_formato_oficial(raw_data):
		return raw_data.duplicate(true)
	if _es_quiz_plano(raw_data):
		return _normalizar_quiz_plano(raw_data)
	return _normalizar_formato_legacy(raw_data)


static func _normalizar_ruta_proyecto(ruta_json: String) -> String:
	if ruta_json.begins_with(DIRECTORIO_PROYECTO_NODOS_ACTUAL):
		return "%s%s" % [
			DIRECTORIO_NODOS_ACTUAL,
			ruta_json.trim_prefix(DIRECTORIO_PROYECTO_NODOS_ACTUAL)
		]
	if ruta_json.begins_with(DIRECTORIO_PROYECTO_NODOS_ANTERIOR):
		return "%s%s" % [
			DIRECTORIO_NODOS_ACTUAL,
			ruta_json.trim_prefix(DIRECTORIO_PROYECTO_NODOS_ANTERIOR)
		]
	if ruta_json.begins_with(DIRECTORIO_PROYECTO_NODOS_LEGACY):
		return "%s%s" % [
			DIRECTORIO_NODOS_LEGACY,
			ruta_json.trim_prefix(DIRECTORIO_PROYECTO_NODOS_LEGACY)
		]
	if ruta_json.begins_with("res://project/"):
		return "res://%s" % ruta_json.trim_prefix("res://project/")
	return ruta_json


static func _resolver_ruta_legacy(ruta_json: String) -> String:
	var ruta_migrada: String = ruta_json
	if ruta_json.begins_with(DIRECTORIO_NODOS_ANTERIOR):
		ruta_migrada = "%s%s" % [
			DIRECTORIO_NODOS_ACTUAL,
			ruta_json.trim_prefix(DIRECTORIO_NODOS_ANTERIOR)
		]
	elif ruta_json.begins_with(DIRECTORIO_NODOS_LEGACY):
		ruta_migrada = "%s%s" % [
			DIRECTORIO_NODOS_ACTUAL,
			ruta_json.trim_prefix(DIRECTORIO_NODOS_LEGACY)
		]
	if ruta_migrada != ruta_json and FileAccess.file_exists(ruta_migrada):
		return ruta_migrada
	if not _puede_buscar_por_nombre(ruta_json):
		return ""
	return _buscar_ruta_json_por_nombre(ruta_json.get_file())


static func _debe_advertir_ruta_legacy(ruta_original: String, ruta_resuelta: String) -> bool:
	if ruta_original == ruta_resuelta:
		return false
	return (
		ruta_original.begins_with(DIRECTORIO_NODOS_LEGACY)
		or ruta_original.begins_with(DIRECTORIO_NODOS_ANTERIOR)
		or ruta_original.begins_with(DIRECTORIO_PROYECTO_NODOS_LEGACY)
		or ruta_original.begins_with(DIRECTORIO_PROYECTO_NODOS_ANTERIOR)
		or ruta_original.begins_with("res://%s" % DIRECTORIO_PROYECTO_NODOS_LEGACY)
	)


static func _puede_buscar_por_nombre(ruta_json: String) -> bool:
	if ruta_json.begins_with(DIRECTORIO_NODOS_LEGACY):
		return true
	if ruta_json.begins_with(DIRECTORIO_NODOS_ANTERIOR):
		return true
	return (
		ruta_json.begins_with(DIRECTORIO_NODOS_ACTUAL)
		and ruta_json.get_base_dir() == DIRECTORIO_NODOS_ACTUAL.trim_suffix("/")
	)


static func _buscar_ruta_json_por_nombre(nombre_archivo: String) -> String:
	var nombre_limpio: String = nombre_archivo.strip_edges()
	if nombre_limpio.is_empty():
		return ""
	return _buscar_en_directorio(DIRECTORIO_NODOS_ACTUAL, nombre_limpio)


static func _buscar_en_directorio(directorio: String, nombre_archivo: String) -> String:
	var carpeta: DirAccess = DirAccess.open(directorio)
	if carpeta == null:
		return ""

	carpeta.list_dir_begin()
	var nombre_hijo: String = carpeta.get_next()
	while not nombre_hijo.is_empty():
		if nombre_hijo.begins_with("."):
			nombre_hijo = carpeta.get_next()
			continue

		var ruta_hijo: String = "%s%s" % [directorio, nombre_hijo]
		if carpeta.current_is_dir():
			var encontrado: String = _buscar_en_directorio("%s/" % ruta_hijo, nombre_archivo)
			if not encontrado.is_empty():
				carpeta.list_dir_end()
				return encontrado
		elif nombre_hijo == nombre_archivo:
			carpeta.list_dir_end()
			return ruta_hijo

		nombre_hijo = carpeta.get_next()
	carpeta.list_dir_end()
	return ""


static func _es_formato_oficial(datos_crudos: Dictionary) -> bool:
	return (
		datos_crudos.has("id")
		and datos_crudos.has("theme")
		and datos_crudos.has("title")
		and datos_crudos.has("difficulty")
		and datos_crudos.has("mode")
		and datos_crudos.has("content")
	)


static func _es_quiz_plano(datos_crudos: Dictionary) -> bool:
	return (
		datos_crudos.has("id")
		and datos_crudos.has("theme")
		and datos_crudos.has("title")
		and datos_crudos.has("difficulty")
		and datos_crudos.has("mode")
		and datos_crudos.has("question")
		and datos_crudos.has("correct_answer")
		and datos_crudos.has("wrong_options")
	)


static func _normalizar_quiz_plano(datos_crudos: Dictionary) -> Dictionary:
	return {
		"id": str(datos_crudos.get("id", "")).strip_edges(),
		"theme": str(datos_crudos.get("theme", "")).strip_edges(),
		"title": str(datos_crudos.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(datos_crudos.get("difficulty", "")).strip_edges()),
		"mode": _normalizar_modo(str(datos_crudos.get("mode", "")).strip_edges()),
		"content": {
			"question": str(datos_crudos.get("question", "")).strip_edges(),
			"correct_answer": str(datos_crudos.get("correct_answer", "")).strip_edges(),
			"wrong_options": _limpiar_textos(datos_crudos.get("wrong_options", [])),
			"visual_resource": str(datos_crudos.get("visual_resource", "")).strip_edges()
		}
	}


static func _normalizar_formato_legacy(datos_crudos: Dictionary) -> Dictionary:
	var datos_nodo: Dictionary = _leer_diccionario(datos_crudos.get("node", {}))
	var datos_actividad: Dictionary = _leer_diccionario(datos_crudos.get("activity", {}))
	var modo: String = _normalizar_modo(str(datos_actividad.get("type", "")).strip_edges())

	match modo:
		MODO_QUIZ_CHOICE:
			var bloque_quiz: Dictionary = _leer_diccionario(datos_crudos.get("question", {}))
			if str(datos_actividad.get("type", "")).strip_edges() == "select_option":
				bloque_quiz = _leer_diccionario(datos_crudos.get("selection", {}))
			return _crear_nodo_quiz(datos_nodo, modo, bloque_quiz)
		MODO_DRAG_DROP:
			return _crear_nodo_drag_drop(
				datos_nodo,
				modo,
				datos_actividad,
				_leer_diccionario(datos_crudos.get("drag_and_drop", {}))
			)
		_:
			return {
				"id": str(datos_nodo.get("question_key", "")).strip_edges(),
				"theme": str(datos_nodo.get("track_key", "")).strip_edges(),
				"title": str(datos_nodo.get("title", "")).strip_edges(),
				"difficulty": _normalizar_dificultad(
					str(datos_nodo.get("difficulty", "")).strip_edges()
				),
				"mode": modo,
				"content": _leer_diccionario(
					datos_crudos.get(
						"title_card",
						datos_crudos.get(
							"drag_and_drop",
							datos_crudos.get(
								"question",
								datos_crudos.get("selection", {})
							)
						)
					)
				)
			}


static func _crear_nodo_quiz(
	datos_nodo: Dictionary,
	modo: String,
	bloque_quiz: Dictionary
) -> Dictionary:
	return {
		"id": str(datos_nodo.get("question_key", "")).strip_edges(),
		"theme": str(datos_nodo.get("track_key", "")).strip_edges(),
		"title": str(datos_nodo.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(datos_nodo.get("difficulty", "")).strip_edges()),
		"mode": modo,
		"content": {
			"question": _primer_texto(
				bloque_quiz,
				["question", "prompt", "instruction", "consigna"]
			),
			"correct_answer": _primer_texto(
				bloque_quiz,
				["correct_answer", "correct_option", "respuesta_correcta", "correct"]
			),
			"wrong_options": _opciones_incorrectas(bloque_quiz),
			"visual_resource": _recurso_visual(bloque_quiz)
		}
	}


static func _crear_nodo_drag_drop(
	datos_nodo: Dictionary,
	modo: String,
	datos_actividad: Dictionary,
	bloque_drag: Dictionary
) -> Dictionary:
	var datos_target: Dictionary = _leer_diccionario(bloque_drag.get("target", {}))
	var targets: Array[Dictionary] = _targets(bloque_drag, datos_target)
	var target_por_defecto: String = ""
	if not targets.is_empty():
		target_por_defecto = str(targets[0].get("id", "")).strip_edges()

	var instruccion: String = _primer_texto(bloque_drag, ["instruction", "prompt"])
	if instruccion.is_empty():
		instruccion = str(datos_actividad.get("instruction", "")).strip_edges()

	return {
		"id": str(datos_nodo.get("question_key", "")).strip_edges(),
		"theme": str(datos_nodo.get("track_key", "")).strip_edges(),
		"title": str(datos_nodo.get("title", "")).strip_edges(),
		"difficulty": _normalizar_dificultad(str(datos_nodo.get("difficulty", "")).strip_edges()),
		"mode": modo,
		"content": {
			"instruction": instruccion,
			"targets": targets,
			"items": _items_drag_drop(bloque_drag, target_por_defecto),
			"success_message": _primer_texto(bloque_drag, ["success_message", "success"]),
			"error_message": _primer_texto(
				bloque_drag,
				["error_message", "error", "failure_message"]
			)
		}
	}


static func _leer_diccionario(valor: Variant) -> Dictionary:
	if valor is Dictionary:
		return valor as Dictionary
	return {}


static func _targets(bloque_drag: Dictionary, target_fallback: Dictionary) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var targets_crudos: Variant = bloque_drag.get("targets", [])
	if targets_crudos is Array:
		for raw_target in targets_crudos:
			var datos_target: Dictionary = _leer_diccionario(raw_target)
			if datos_target.is_empty():
				continue
			targets.append({
				"id": str(datos_target.get("id", "")).strip_edges(),
				"label": str(datos_target.get("label", "")).strip_edges()
			})

	if not targets.is_empty() or target_fallback.is_empty():
		return targets

	targets.append({
		"id": str(target_fallback.get("id", "")).strip_edges(),
		"label": str(target_fallback.get("label", "")).strip_edges()
	})
	return targets


static func _items_drag_drop(
	bloque_drag: Dictionary,
	target_por_defecto: String
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var items_crudos: Variant = bloque_drag.get("items", [])
	if not items_crudos is Array:
		return items

	for raw_item in items_crudos:
		var datos_item: Dictionary = _leer_diccionario(raw_item)
		if datos_item.is_empty():
			continue

		var target_correcto: String = str(datos_item.get("correct_target", "")).strip_edges()
		if target_correcto.is_empty() and bool(datos_item.get("is_correct", false)):
			target_correcto = target_por_defecto

		items.append({
			"id": str(datos_item.get("id", "")).strip_edges(),
			"label": str(datos_item.get("label", "")).strip_edges(),
			"image": _primer_texto(datos_item, ["image", "image_path", "sprite"]),
			"correct_target": target_correcto
		})

	return items


static func _opciones_incorrectas(bloque_quiz: Dictionary) -> Array[String]:
	var opciones_incorrectas: Array[String] = _limpiar_textos(
		bloque_quiz.get(
			"wrong_options",
			bloque_quiz.get("wrong_answers", bloque_quiz.get("opciones_incorrectas", []))
		)
	)
	if not opciones_incorrectas.is_empty():
		return opciones_incorrectas

	var respuesta_correcta: String = _primer_texto(
		bloque_quiz,
		["correct_answer", "correct_option", "respuesta_correcta", "correct"]
	)
	var opciones: Array[String] = _limpiar_textos(
		bloque_quiz.get("options", bloque_quiz.get("opciones", bloque_quiz.get("choices", [])))
	)
	for opcion in opciones:
		if opcion != respuesta_correcta:
			opciones_incorrectas.append(opcion)
	return opciones_incorrectas


static func _recurso_visual(bloque_quiz: Dictionary) -> String:
	var assets: Dictionary = _leer_diccionario(bloque_quiz.get("assets", {}))
	var imagen_interna: String = str(assets.get("image_path", "")).strip_edges()
	if not imagen_interna.is_empty():
		return imagen_interna
	return _primer_texto(bloque_quiz, ["visual_resource", "image_path", "imagen_path"])


static func _primer_texto(fuente: Dictionary, claves: Array[String]) -> String:
	for clave in claves:
		if not fuente.has(clave):
			continue
		var valor: String = str(fuente.get(clave, "")).strip_edges()
		if not valor.is_empty():
			return valor
	return ""


static func _normalizar_modo(modo: String) -> String:
	var modo_limpio: String = modo.strip_edges()
	if modo_limpio.is_empty():
		return MODO_QUIZ_CHOICE
	if modo_limpio == "select_option":
		return MODO_QUIZ_CHOICE
	if modo_limpio == "drag_to_target":
		return MODO_DRAG_DROP
	return modo_limpio


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
