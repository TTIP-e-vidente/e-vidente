extends RefCounted
class_name AdaptadorContenidoViejo

# LEGACY_COMPAT: Usado por ContentNormalizer.
# No agregar lógica nueva aquí; el contenido nuevo entra por NodeContentLoader.

# Adapta formatos viejos para no romper contenido existente.
# No es el camino recomendado para contenido nuevo.

const MODO_QUIZ_CHOICE := "quiz_choice"
const MODO_DRAG_DROP := "drag_drop"
const DIRECTORIO_NODOS_ACTUAL := "res://contenido/nodos/"
const TARGET_ARRASTRE_POR_DEFECTO := "plato"
const LABEL_TARGET_ARRASTRE_POR_DEFECTO := "Plato"

const DIRECTORIO_ITEMS_ACTUAL := "res://items/"
const DIRECTORIO_PROYECTO_ITEMS_ACTUAL := "project/items/"

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
				"CargadorDeContenidoDeNodo: ruta legacy detectada. Usa %s en lugar de %s."
				% [legacy_path, clean_path]
			)
		return legacy_path

	return res_path


static func adaptar(datos_crudos: Dictionary) -> Dictionary:
	return _adaptar_interno(datos_crudos, [])


static func _adaptar_interno(datos_crudos: Dictionary, pool_stack: Array[String]) -> Dictionary:
	if _es_formato_oficial(datos_crudos):
		return _normalizar_formato_oficial(datos_crudos, pool_stack)
	if _es_quiz_plano(datos_crudos):
		return _normalizar_quiz_plano(datos_crudos)
	return _normalizar_formato_legacy(datos_crudos)


static func _normalizar_formato_oficial(
	datos_crudos: Dictionary,
	pool_stack: Array[String] = []
) -> Dictionary:
	var datos_normalizados: Dictionary = datos_crudos.duplicate(true)
	if _normalizar_modo(str(datos_normalizados.get("mode", "")).strip_edges()) != MODO_DRAG_DROP:
		return datos_normalizados

	var contenido: Dictionary = _leer_diccionario(datos_normalizados.get("content", {}))
	contenido = _resolver_pool_ref_drag_drop(contenido, pool_stack)
	if not _usa_contenido_arrastre_tipo_level_resource(contenido):
		datos_normalizados["content"] = contenido
		return datos_normalizados

	datos_normalizados["content"] = _normalizar_contenido_drag_drop_tipo_level_resource(contenido)
	return datos_normalizados


static func _resolver_pool_ref_drag_drop(
	contenido: Dictionary,
	pool_stack: Array[String]
) -> Dictionary:
	var pool_ref: String = _primer_texto(contenido, ["pool_ref", "pool_json_path"])
	if pool_ref.is_empty():
		return contenido

	var ruta_pool: String = resolver_ruta_json(pool_ref)
	if ruta_pool.is_empty():
		return _contenido_sin_clave_pool(contenido)
	if pool_stack.has(ruta_pool):
		push_error("AdaptadorContenidoViejo: pool_ref circular detectado: %s" % ruta_pool)
		return _contenido_sin_clave_pool(contenido)

	var datos_pool_crudos: Dictionary = _leer_json_desde_ruta(ruta_pool)
	if datos_pool_crudos.is_empty():
		push_warning("AdaptadorContenidoViejo: no se pudo cargar pool_ref: %s" % ruta_pool)
		return _contenido_sin_clave_pool(contenido)

	var siguiente_pool_stack: Array[String] = pool_stack.duplicate()
	siguiente_pool_stack.append(ruta_pool)
	if _normalizar_modo(str(datos_pool_crudos.get("mode", "")).strip_edges()) != MODO_DRAG_DROP:
		push_warning("AdaptadorContenidoViejo: pool_ref no apunta a un drag_drop: %s" % ruta_pool)
		return _contenido_sin_clave_pool(contenido)

	var contenido_pool: Dictionary = _leer_diccionario(datos_pool_crudos.get("content", {}))
	contenido_pool = _resolver_pool_ref_drag_drop(contenido_pool, siguiente_pool_stack)
	return _combinar_contenido_drag_drop(contenido_pool, contenido)


static func _contenido_sin_clave_pool(contenido: Dictionary) -> Dictionary:
	var contenido_limpio: Dictionary = contenido.duplicate(true)
	contenido_limpio.erase("pool_ref")
	contenido_limpio.erase("pool_json_path")
	return contenido_limpio


static func _combinar_contenido_drag_drop(
	contenido_pool: Dictionary,
	contenido_override: Dictionary
) -> Dictionary:
	var contenido_combinado: Dictionary = contenido_pool.duplicate(true)
	for clave in contenido_override.keys():
		if [
			"pool_ref",
			"pool_json_path",
			"itemsPositivosExtra",
			"itemsNegativosExtra",
			"itemsExtra",
			"targetsExtra",
		].has(clave):
			continue
		contenido_combinado[clave] = contenido_override[clave]

	_agregar_array_extra_drag_drop(
		contenido_combinado,
		contenido_override,
		"itemsPositivos",
		"itemsPositivosExtra"
	)
	_agregar_array_extra_drag_drop(
		contenido_combinado,
		contenido_override,
		"itemsNegativos",
		"itemsNegativosExtra"
	)
	_agregar_array_extra_drag_drop(
		contenido_combinado,
		contenido_override,
		"items",
		"itemsExtra"
	)
	_agregar_array_extra_drag_drop(
		contenido_combinado,
		contenido_override,
		"targets",
		"targetsExtra"
	)
	return contenido_combinado


static func _agregar_array_extra_drag_drop(
	contenido_combinado: Dictionary,
	contenido_override: Dictionary,
	clave_base: String,
	clave_extra: String
) -> void:
	var extras: Variant = contenido_override.get(clave_extra, [])
	if not extras is Array:
		return
	if not contenido_combinado.has(clave_base):
		contenido_combinado[clave_base] = []
	var base: Variant = contenido_combinado.get(clave_base, [])
	if not base is Array:
		return
	contenido_combinado[clave_base] = (
		(base as Array).duplicate(true) + (extras as Array).duplicate(true)
	)


static func _leer_json_desde_ruta(ruta_json: String) -> Dictionary:
	var ruta_limpia: String = resolver_ruta_json(ruta_json)
	if ruta_limpia.is_empty() or not FileAccess.file_exists(ruta_limpia):
		return {}
	var archivo: FileAccess = FileAccess.open(ruta_limpia, FileAccess.READ)
	if archivo == null:
		return {}
	var parser := JSON.new()
	if parser.parse(archivo.get_as_text()) != OK:
		return {}
	var datos_parseados: Variant = parser.get_data()
	if not datos_parseados is Dictionary:
		return {}
	return datos_parseados as Dictionary


static func _usa_formato_arrastre_tipo_level_resource(datos_crudos: Dictionary) -> bool:
	if _normalizar_modo(str(datos_crudos.get("mode", "")).strip_edges()) != MODO_DRAG_DROP:
		return false
	var contenido: Dictionary = _leer_diccionario(datos_crudos.get("content", {}))
	return _usa_contenido_arrastre_tipo_level_resource(contenido)


static func _usa_contenido_arrastre_tipo_level_resource(contenido: Dictionary) -> bool:
	for clave in [
		"itemsPositivos",
		"itemsNegativos",
		"items_positivos",
		"items_negativos",
		"cantidadPositivos",
		"cantidadNegativos",
		"cantidad_positivos",
		"cantidad_negativos",
	]:
		if contenido.has(clave):
			return true
	return false


static func _normalizar_contenido_drag_drop_tipo_level_resource(
	contenido: Dictionary
) -> Dictionary:
	var target_fallback := {
		"id": _primer_texto(contenido, ["targetId", "target_id"]),
		"label": _primer_texto(contenido, ["targetLabel", "target_label"]),
	}
	if str(target_fallback.get("id", "")).strip_edges().is_empty():
		target_fallback["id"] = TARGET_ARRASTRE_POR_DEFECTO
	if str(target_fallback.get("label", "")).strip_edges().is_empty():
		target_fallback["label"] = LABEL_TARGET_ARRASTRE_POR_DEFECTO

	var targets: Array[Dictionary] = _targets(contenido, target_fallback)
	var target_por_defecto: String = str(targets[0].get("id", TARGET_ARRASTRE_POR_DEFECTO))
	var items_positivos: Array[Dictionary] = _items_drag_drop_tipo_level_resource(
		contenido.get("itemsPositivos", contenido.get("items_positivos", [])),
		target_por_defecto,
		true
	)
	var items_negativos: Array[Dictionary] = _items_drag_drop_tipo_level_resource(
		contenido.get("itemsNegativos", contenido.get("items_negativos", [])),
		target_por_defecto,
		false
	)
	var contenido_normalizado := {
		"teaching_key": str(contenido.get("teaching_key", "")).strip_edges(),
		"instruction": _primer_texto(contenido, ["instruction", "prompt", "consigna"]),
		"targets": targets,
		"items": items_positivos + items_negativos,
	}
	_agregar_cantidades_tipo_level_resource(
		contenido,
		contenido_normalizado,
		items_positivos.size(),
		items_negativos.size()
	)
	if contenido.has("mostrar_ayuda_visual"):
		contenido_normalizado["mostrar_ayuda_visual"] = bool(
			contenido.get("mostrar_ayuda_visual", true)
		)
	return contenido_normalizado


static func _agregar_cantidades_tipo_level_resource(
	contenido: Dictionary,
	contenido_normalizado: Dictionary,
	total_positivos: int,
	total_negativos: int
) -> void:
	var cantidad_positivos: int = _leer_entero_arrastre(
		contenido,
		["cantidadPositivos", "cantidad_positivos"],
		total_positivos
	)
	var cantidad_negativos: int = _leer_entero_arrastre(
		contenido,
		["cantidadNegativos", "cantidad_negativos"],
		total_negativos
	)
	if cantidad_positivos > 0 or cantidad_negativos > 0:
		contenido_normalizado["elementos_maximos"] = maxi(
			1,
			cantidad_positivos + cantidad_negativos
		)
		contenido_normalizado["distractores_maximos"] = maxi(0, cantidad_negativos)


static func _leer_entero_arrastre(
	contenido: Dictionary,
	claves: Array[String],
	valor_por_defecto: int
) -> int:
	for clave in claves:
		if not contenido.has(clave):
			continue
		return int(contenido.get(clave, valor_por_defecto))
	return valor_por_defecto


static func _items_drag_drop_tipo_level_resource(
	items_crudos: Variant,
	target_por_defecto: String,
	es_positivo: bool
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not items_crudos is Array:
		return items

	for raw_item in items_crudos:
		var item_normalizado: Dictionary = _normalizar_item_tipo_level_resource(
			raw_item,
			target_por_defecto,
			es_positivo
		)
		if item_normalizado.is_empty():
			continue
		items.append(item_normalizado)
	return items


static func _normalizar_item_tipo_level_resource(
	raw_item: Variant,
	target_por_defecto: String,
	es_positivo: bool
) -> Dictionary:
	var datos_item: Dictionary = _leer_diccionario(raw_item)
	var ruta_item: String = ""
	if raw_item is String:
		ruta_item = str(raw_item).strip_edges()
	else:
		ruta_item = _primer_texto(datos_item, ["item_path", "resource_path", "path"])

	var datos_recurso: Dictionary = _cargar_item_de_recurso(ruta_item)
	var item_id: String = str(datos_item.get("id", datos_recurso.get("id", ""))).strip_edges()
	if item_id.is_empty():
		return {}

	var label: String = str(
		datos_item.get("label", datos_recurso.get("label", item_id))
	).strip_edges()
	var image: String = _primer_texto(datos_item, ["image", "image_path", "sprite"])
	if image.is_empty():
		image = str(datos_recurso.get("image", "")).strip_edges()

	var item_normalizado := {
		"id": item_id,
		"label": label,
		"image": image,
		"correct_target": target_por_defecto if es_positivo else "",
	}

	var categoria: String = _primer_texto(datos_item, ["category", "categoria"])
	if categoria.is_empty():
		categoria = str(datos_recurso.get("category", "")).strip_edges()
	if not categoria.is_empty():
		item_normalizado["category"] = categoria

	var info_image: String = _primer_texto(datos_item, ["info_image", "info", "info_path"])
	if info_image.is_empty():
		info_image = str(datos_recurso.get("info_image", "")).strip_edges()
	if not info_image.is_empty():
		item_normalizado["info_image"] = info_image

	return item_normalizado


static func _cargar_item_de_recurso(ruta_item: String) -> Dictionary:
	var ruta_limpia: String = _normalizar_ruta_item(ruta_item)
	if ruta_limpia.is_empty():
		return {}

	var recurso: Resource = load(ruta_limpia) as Resource
	if recurso == null:
		return {}

	var sprite: Texture2D = recurso.get("sprite") as Texture2D
	var info: Texture2D = recurso.get("info") as Texture2D
	var categoria: String = ""
	if recurso.get("categoria") != null:
		categoria = str(recurso.get("categoria")).strip_edges()
	var item_id: String = ruta_limpia.get_file().get_basename().strip_edges()
	return {
		"id": item_id,
		"label": item_id.replace("_", " ").replace("-", " "),
		"image": sprite.resource_path if sprite != null else "",
		"info_image": info.resource_path if info != null else "",
		"category": categoria,
	}


static func _normalizar_ruta_item(ruta_item: String) -> String:
	var ruta_limpia: String = ruta_item.strip_edges()
	if ruta_limpia.is_empty():
		return ""
	if ruta_limpia.begins_with(DIRECTORIO_PROYECTO_ITEMS_ACTUAL):
		return "%s%s" % [
			DIRECTORIO_ITEMS_ACTUAL,
			ruta_limpia.trim_prefix(DIRECTORIO_PROYECTO_ITEMS_ACTUAL)
		]
	if ruta_limpia.begins_with("res://project/"):
		return "res://%s" % ruta_limpia.trim_prefix("res://project/")
	return ruta_limpia


static func normalizar_datos_nodo(raw_data: Dictionary) -> Dictionary:
	return adaptar(raw_data)


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
			"items": _items_drag_drop(bloque_drag, target_por_defecto)
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
