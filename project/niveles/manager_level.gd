extends Node
class_name ManagerLevel

const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)
const LevelItemScript := preload("res://resources/level_item.gd")
const GameTrackItemPoolCatalogScript := preload(
	"res://niveles/content/catalog/GameTrackItemPoolCatalog.gd"
)
const LevelResourceScript := preload("res://resources/level_resource.gd")
const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

const PLATE_SORT_MECHANIC_TYPE := "plate_sort"
const MAX_PLATE_COLUMNS := 3
const PLATE_ITEM_COLUMN_SPACING := 78.0
const PLATE_ITEM_ROW_SPACING := 48.0
const PLATE_ITEM_VERTICAL_OFFSET := -12.0
const PARTIAL_SAVE_UNIT_SINGULAR := "alimento correcto en el plato"
const PARTIAL_SAVE_UNIT_PLURAL := "alimentos correctos en el plato"
const RUTA_ESCENA_ELEMENTO_ARRASTRE := "res://items/item_level.tscn"
const RUTA_TEXTURA_ELEMENTO_POR_DEFECTO := "res://assets-sistema/interfaz/desayuno.png"

@export var level_resource: Resource = null
@export var level_resource_path := ""

@onready var plato = %Plato

var condition_sprite: Sprite2D = null
var meal_sprite: Sprite2D = null
var teaching_sprite: Sprite2D = null
var level_items: Array = []
var active_track_key: String = ""
var active_run_index: int = 1
var active_run_data: Dictionary = {}
var active_mechanic_type: String = ""
var active_positive_item_count: int = 0
var active_negative_item_count: int = 0
var active_category_code: String = ""
var _configuracion_dificultad_arrastre: Dictionary = {}
var _texturas_info_por_sprite: Dictionary = {}


# --- Flujo público del nivel --------------------------------------------------
func iniciar_nivel_sesion(track_key: String, level_scene: Node) -> void:
	if not _conectar_escena_nodos(level_scene):
		return

	active_track_key = track_key.strip_edges()
	_asegurar_recurso_nivel_cargado()

	var saved_level_state: Dictionary = _obtener_estado_guardado_actual()
	active_run_index = _resolver_indice_partida(saved_level_state)
	_cargar_partida_actual(saved_level_state)


func iniciar_desde_datos_de_arrastre(track_key: String, contenido_arrastre: Dictionary, level_scene: Node) -> bool:
	# Inicializa el nivel usando directamente el contenido (content) de un JSON de arrastre.
	# No reemplaza el flujo legacy: es un entrypoint mínimo para consumir JSON oficial.
	if not _conectar_escena_nodos(level_scene):
		return false

	active_track_key = track_key.strip_edges()
	_preparar_runtime_de_arrastre_desde_json()

	var datos_arrastre: Dictionary = _extraer_datos_de_arrastre(contenido_arrastre)
	var escena_elemento: PackedScene = _cargar_escena_elemento_de_arrastre()
	if escena_elemento == null:
		return false

	var elementos_de_arrastre: Dictionary = _crear_elementos_desde_datos_de_arrastre(
		datos_arrastre.get("elementos", []),
		escena_elemento
	)
	if not _hay_elementos_de_arrastre_validos(elementos_de_arrastre):
		push_warning("ManagerLevel: el JSON de arrastre no generó elementos runtime válidos.")
		return false

	_preparar_recurso_de_arrastre(
		contenido_arrastre,
		datos_arrastre.get("objetivos", []),
		elementos_de_arrastre,
		level_scene
	)
	active_run_data = _construir_datos_de_partida_de_arrastre()
	return _finalizar_arranque_de_arrastre_desde_json()


func _preparar_runtime_de_arrastre_desde_json() -> void:
	limpiar_tiempo_ejecucion_elementos()
	active_mechanic_type = PLATE_SORT_MECHANIC_TYPE


func _preparar_recurso_de_arrastre(
	contenido_arrastre: Dictionary,
	objetivos_crudos: Array,
	elementos_de_arrastre: Dictionary,
	level_scene: Node
) -> void:
	_aplicar_cantidad_de_elementos_de_arrastre(elementos_de_arrastre)
	_asegurar_recurso_nivel_para_arrastre()
	_guardar_contenido_de_arrastre_en_recurso(
		contenido_arrastre,
		objetivos_crudos,
		elementos_de_arrastre,
		level_scene
	)
	_aplicar_configuracion_de_dificultad_arrastre()


func _construir_datos_de_partida_de_arrastre() -> Dictionary:
	var mechanic_payload: Dictionary = {}
	if (
		level_resource != null
		and level_resource.mechanic_payload is Dictionary
		and not (level_resource.mechanic_payload as Dictionary).is_empty()
	):
		mechanic_payload = (level_resource.mechanic_payload as Dictionary).duplicate(true)
	var ruta_ensenanza := ""
	if level_resource != null and level_resource.ensenanza != null:
		ruta_ensenanza = str(level_resource.ensenanza.resource_path).strip_edges()
	return {
		"mechanic_type": active_mechanic_type,
		"mechanic_payload": mechanic_payload,
		"negative_count": active_negative_item_count,
		"positive_count": active_positive_item_count,
		"category": active_category_code,
		"meal_texture_path": "",
		"condition_texture_path": "",
		"teaching_texture_path": ruta_ensenanza,
	}


func _finalizar_arranque_de_arrastre_desde_json() -> bool:
	_instanciar_elementos_de_arrastre()
	if level_items.is_empty():
		push_warning("ManagerLevel: no se pudieron instanciar comidas de arrastre desde el JSON.")
		return false
	level_items.shuffle()
	distribuir_tiempo_ejecucion_elementos()
	_aplicar_ayuda_visual_de_arrastre()
	return true


func _extraer_datos_de_arrastre(contenido_arrastre: Dictionary) -> Dictionary:
	var elementos: Array = []
	var objetivos: Array = []
	if contenido_arrastre is Dictionary:
		elementos = contenido_arrastre.get("items", []) if contenido_arrastre.has("items") else contenido_arrastre.get("content", {}).get("items", [])
		objetivos = contenido_arrastre.get("targets", []) if contenido_arrastre.has("targets") else contenido_arrastre.get("content", {}).get("targets", [])
	return {
		"elementos": elementos,
		"objetivos": objetivos,
	}


func _cargar_escena_elemento_de_arrastre() -> PackedScene:
	var escena_elemento: PackedScene = load(RUTA_ESCENA_ELEMENTO_ARRASTRE) as PackedScene
	if escena_elemento == null:
		push_warning(
			"ManagerLevel: no se pudo cargar la escena de arrastre %s."
			% RUTA_ESCENA_ELEMENTO_ARRASTRE
		)
	return escena_elemento


func _crear_elementos_desde_datos_de_arrastre(
	elementos_crudos: Array,
	escena_elemento: PackedScene
) -> Dictionary:
	var positivos: Array = []
	var negativos: Array = []
	for elemento_crudo in elementos_crudos:
		var nivel_item: Resource = _crear_elemento_de_arrastre_desde_datos(
			elemento_crudo,
			escena_elemento
		)
		if nivel_item == null:
			continue
		if bool(nivel_item.esPositivo):
			positivos.append(nivel_item)
		else:
			negativos.append(nivel_item)
	return {
		"positivos": positivos,
		"negativos": negativos,
	}


func _crear_elemento_de_arrastre_desde_datos(
	elemento_crudo: Variant,
	escena_elemento: PackedScene
) -> Resource:
	if not elemento_crudo is Dictionary:
		return null
	var datos_elemento: Dictionary = elemento_crudo as Dictionary
	var nivel_item = LevelItemScript.new()
	var textura_elemento: Texture2D = _resolver_textura_elemento_arrastre(datos_elemento)
	var textura_info: Texture2D = _resolver_textura_info_elemento_arrastre(
		datos_elemento,
		textura_elemento
	)
	nivel_item.sprite = textura_elemento
	nivel_item.escena = escena_elemento
	nivel_item.info = textura_info if textura_info != null else nivel_item.sprite
	nivel_item.categoria = str(datos_elemento.get("category", "")).strip_edges()
	nivel_item.esPositivo = str(datos_elemento.get("correct_target", "")).strip_edges() != ""
	return nivel_item


func _hay_elementos_de_arrastre_validos(elementos_de_arrastre: Dictionary) -> bool:
	var positivos: Array = elementos_de_arrastre.get("positivos", [])
	var negativos: Array = elementos_de_arrastre.get("negativos", [])
	return not positivos.is_empty() or not negativos.is_empty()


func _aplicar_cantidad_de_elementos_de_arrastre(elementos_de_arrastre: Dictionary) -> void:
	var positivos: Array = elementos_de_arrastre.get("positivos", [])
	var negativos: Array = elementos_de_arrastre.get("negativos", [])
	active_positive_item_count = positivos.size()
	active_negative_item_count = negativos.size()


func _asegurar_recurso_nivel_para_arrastre() -> void:
	if not level_resource:
		level_resource = LevelResourceScript.new()


func _guardar_contenido_de_arrastre_en_recurso(
	contenido_arrastre: Dictionary,
	objetivos_crudos: Array,
	elementos_de_arrastre: Dictionary,
	level_scene: Node
) -> void:
	var positivos: Array = elementos_de_arrastre.get("positivos", [])
	var negativos: Array = elementos_de_arrastre.get("negativos", [])
	level_resource.itemsPositivos = positivos
	level_resource.itemsNegativos = negativos
	level_resource.cantidadPositivos = active_positive_item_count
	level_resource.cantidadNegativos = active_negative_item_count
	level_resource.ensenanza = _resolver_textura_de_ensenanza_para_arrastre(level_scene)
	level_resource.mechanic_payload = {
		"targets": objetivos_crudos,
		"instruction": contenido_arrastre.get("instruction", ""),
	}
	if is_instance_valid(teaching_sprite):
		teaching_sprite.texture = level_resource.ensenanza


func _resolver_textura_de_ensenanza_para_arrastre(level_scene: Node) -> Texture2D:
	var textura_por_nodo: Texture2D = _resolver_textura_de_ensenanza_por_nodo(level_scene)
	if textura_por_nodo != null:
		return textura_por_nodo

	var numero_nivel: int = _obtener_numero_nivel_para_arrastre(level_scene)
	if numero_nivel <= 0:
		return null
	var definicion_capitulo: Dictionary = Global.obtener_capitulo_partida_definicion(
		active_track_key,
		numero_nivel,
		max(1, active_run_index)
	)
	if definicion_capitulo.is_empty():
		return null
	var ruta_ensenanza: String = str(
		definicion_capitulo.get("teaching_texture_path", "")
	).strip_edges()
	if ruta_ensenanza.is_empty():
		return null
	return GameChapterAssetCatalogScript.resolver_textura(ruta_ensenanza)


func _resolver_textura_de_ensenanza_por_nodo(level_scene: Node) -> Texture2D:
	var clave_ensenanza: String = _obtener_clave_ensenanza_explicita(level_scene)
	if clave_ensenanza.is_empty():
		clave_ensenanza = _inferir_clave_ensenanza_desde_nodo(level_scene)
	if clave_ensenanza.is_empty():
		return null

	var ruta_ensenanza: String = str(
		GameChapterAssetCatalogScript.TEACHING_TEXTURE_PATHS.get(clave_ensenanza, "")
	).strip_edges()
	if ruta_ensenanza.is_empty():
		return null
	return GameChapterAssetCatalogScript.resolver_textura(ruta_ensenanza)


func _obtener_clave_ensenanza_explicita(level_scene: Node) -> String:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	var clave: String = _leer_clave_ensenanza_de_diccionario(juego_actual)
	if not clave.is_empty():
		return clave

	var sesion_jugable: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	clave = _leer_clave_ensenanza_de_diccionario(sesion_jugable)
	if not clave.is_empty():
		return clave

	if is_instance_valid(level_scene):
		var contexto_variant: Variant = level_scene.get("_contexto_nodo_mapa")
		if contexto_variant is Dictionary:
			clave = _leer_clave_ensenanza_de_diccionario(contexto_variant as Dictionary)
			if not clave.is_empty():
				return clave
	return ""


func _leer_clave_ensenanza_de_diccionario(datos: Dictionary) -> String:
	for clave_campo in ["teaching_key", "ensenanza_key", "clave_ensenanza"]:
		var clave: String = str(datos.get(clave_campo, "")).strip_edges()
		if not clave.is_empty():
			return clave
	return ""


func _inferir_clave_ensenanza_desde_nodo(level_scene: Node) -> String:
	var node_key: String = _obtener_clave_nodo_de_contexto(level_scene)
	var numero_receta: int = _extraer_numero_de_receta(node_key)
	if numero_receta <= 0:
		return ""

	var track_definition: Dictionary = GameTrackCatalog.obtener_definicion_pista(active_track_key)
	var prefix_list_variant: Variant = track_definition.get("teaching_key_prefixes", [])
	if not prefix_list_variant is Array:
		return ""
	var prefix_list: Array = prefix_list_variant as Array
	if prefix_list.is_empty():
		return ""
	var prefix := str(prefix_list[0]).strip_edges()
	if prefix.is_empty():
		return ""

	var clave_ensenanza := "%s%d" % [prefix, numero_receta]
	if not GameChapterAssetCatalogScript.TEACHING_TEXTURE_PATHS.has(clave_ensenanza):
		return ""
	return clave_ensenanza


func _obtener_clave_nodo_de_contexto(level_scene: Node) -> String:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	var clave_nodo: String = str(juego_actual.get("node_key", "")).strip_edges()
	if not clave_nodo.is_empty():
		return clave_nodo

	var sesion_jugable: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	clave_nodo = str(sesion_jugable.get("node_key", "")).strip_edges()
	if not clave_nodo.is_empty():
		return clave_nodo

	if is_instance_valid(level_scene):
		var contexto_variant: Variant = level_scene.get("_contexto_nodo_mapa")
		if contexto_variant is Dictionary:
			var contexto_nodo: Dictionary = contexto_variant as Dictionary
			clave_nodo = str(contexto_nodo.get("node_key", "")).strip_edges()
			if not clave_nodo.is_empty():
				return clave_nodo
	return ""


func _extraer_numero_de_receta(node_key: String) -> int:
	var marcador := "receta_"
	var inicio := node_key.find(marcador)
	if inicio < 0:
		return 0
	var cursor := inicio + marcador.length()
	var digitos := ""
	while cursor < node_key.length():
		var caracter := node_key.substr(cursor, 1)
		if not caracter.is_valid_int():
			break
		digitos += caracter
		cursor += 1
	return int(digitos) if not digitos.is_empty() else 0


func _obtener_numero_nivel_para_arrastre(level_scene: Node) -> int:
	var juego_actual: Dictionary = Global.obtener_juego_actual_de_partida()
	var numero_nivel: int = int(juego_actual.get("level_number", 0))
	if numero_nivel > 0:
		return numero_nivel

	var sesion_jugable: Dictionary = Global.obtener_sesion_nodo_jugable_activo()
	numero_nivel = int(sesion_jugable.get("level_number", sesion_jugable.get("nivel_id", 0)))
	if numero_nivel > 0:
		return numero_nivel

	if is_instance_valid(level_scene):
		var contexto_variant: Variant = level_scene.get("_contexto_nodo_mapa")
		if contexto_variant is Dictionary:
			var contexto_nodo: Dictionary = contexto_variant as Dictionary
			numero_nivel = int(
				contexto_nodo.get("level_number", contexto_nodo.get("nivel_id", 0))
			)
			if numero_nivel > 0:
				return numero_nivel

	return int(Global.current_level)


func _instanciar_elementos_de_arrastre() -> void:
	for i in range(min(active_positive_item_count, level_resource.itemsPositivos.size())):
		generar_nivel_elemento(level_resource.itemsPositivos[i], "positive_%d" % i, true)
	for j in range(min(active_negative_item_count, level_resource.itemsNegativos.size())):
		generar_nivel_elemento(level_resource.itemsNegativos[j], "negative_%d" % j, false)


func _resolver_textura_elemento_arrastre(elemento_crudo: Dictionary) -> Texture2D:
	var ruta_textura: String = str(elemento_crudo.get("image", "")).strip_edges()
	var textura_elemento: Texture2D = GameChapterAssetCatalogScript.resolver_textura(ruta_textura)
	if textura_elemento != null:
		return textura_elemento

	var identificador_elemento: String = str(elemento_crudo.get("id", "sin_id")).strip_edges()
	push_warning(
		"ManagerLevel: no se pudo cargar la textura del elemento '%s' (%s). Se usará una textura por defecto."
		% [identificador_elemento, ruta_textura]
	)
	return load(RUTA_TEXTURA_ELEMENTO_POR_DEFECTO) as Texture2D


func _resolver_textura_info_elemento_arrastre(
	elemento_crudo: Dictionary,
	textura_elemento: Texture2D
) -> Texture2D:
	var ruta_textura: String = str(elemento_crudo.get("image", "")).strip_edges()
	var texturas_info_por_sprite := _obtener_texturas_info_por_sprite()
	if not ruta_textura.is_empty() and texturas_info_por_sprite.has(ruta_textura):
		return texturas_info_por_sprite.get(ruta_textura) as Texture2D
	if textura_elemento != null:
		var ruta_textura_cargada := textura_elemento.resource_path.strip_edges()
		if (
			not ruta_textura_cargada.is_empty()
			and texturas_info_por_sprite.has(ruta_textura_cargada)
		):
			return texturas_info_por_sprite.get(ruta_textura_cargada) as Texture2D
	var ruta_info_inferida := _inferir_ruta_info_desde_sprite(ruta_textura)
	if ruta_info_inferida.is_empty():
		return null
	return load(ruta_info_inferida) as Texture2D


func _obtener_texturas_info_por_sprite() -> Dictionary:
	if not _texturas_info_por_sprite.is_empty():
		return _texturas_info_por_sprite
	var directorio_items := DirAccess.open("res://items")
	if directorio_items == null:
		return _texturas_info_por_sprite
	directorio_items.list_dir_begin()
	while true:
		var nombre_archivo := directorio_items.get_next()
		if nombre_archivo.is_empty():
			break
		if directorio_items.current_is_dir() or not nombre_archivo.ends_with(".tres"):
			continue
		var item_recurso := load("res://items/%s" % nombre_archivo)
		if item_recurso == null:
			continue
		var textura_sprite := item_recurso.get("sprite") as Texture2D
		var textura_info := item_recurso.get("info") as Texture2D
		if textura_sprite == null or textura_info == null:
			continue
		var ruta_sprite := textura_sprite.resource_path.strip_edges()
		if ruta_sprite.is_empty():
			continue
		_texturas_info_por_sprite[ruta_sprite] = textura_info
	directorio_items.list_dir_end()
	return _texturas_info_por_sprite


func _inferir_ruta_info_desde_sprite(ruta_textura: String) -> String:
	if ruta_textura.is_empty():
		return ""
	var nombre_base := ruta_textura.get_file().get_basename()
	if nombre_base.ends_with("-0"):
		nombre_base = nombre_base.substr(0, nombre_base.length() - 2)
	var ruta_info := "res://assets-sistema/iconos/alimentos-info/%s-info.png" % nombre_base
	if ResourceLoader.exists(ruta_info, "Texture2D"):
		return ruta_info
	return ""


func establecer_configuracion_de_dificultad_arrastre(configuracion: Dictionary) -> void:
	_configuracion_dificultad_arrastre = configuracion.duplicate(true)


func avanzar_a_siguiente_partida() -> bool:
	if active_run_index >= obtener_total_partidas():
		return false
	active_run_index += 1
	_cargar_partida_actual({"run_index": active_run_index})
	return true


func obtener_actual_partida_indice() -> int:
	return active_run_index


func obtener_total_partidas() -> int:
	return max(1, Global.obtener_capitulo_partida_cantidad(active_track_key, Global.current_level))


func establecer_tiempo_ejecucion_elementos_interactuable(enabled: bool) -> void:
	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue
		if runtime_item.has_method("set_interaction_enabled"):
			runtime_item.set_interaction_enabled(enabled)


# --- Guardado parcial ---------------------------------------------------------
func construir_parcial_nivel_estado() -> Dictionary:
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return {}

	var mechanic_state: Dictionary = _construir_estado_guardado_mecanica()
	if mechanic_state.is_empty() and active_run_index <= 1:
		return {}

	return {
		"run_index": active_run_index,
		"mechanic_type": active_mechanic_type,
		"mechanic_state": mechanic_state
	}


func almacenar_parcial_nivel_estado(track_key: String) -> int:
	var partial_level_state: Dictionary = construir_parcial_nivel_estado()
	Global.establecer_parcial_nivel_estado(
		track_key,
		Global.current_level,
		partial_level_state
	)
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		return 0
	return obtener_positivo_elementos_in_plato_cantidad()


func formatear_parcial_guardar_progreso(saved_positive_count: int) -> String:
	if saved_positive_count <= 0:
		return "Capitulo %d listo para retomar" % Global.current_level
	var unit: String = PARTIAL_SAVE_UNIT_SINGULAR
	if saved_positive_count != 1:
		unit = PARTIAL_SAVE_UNIT_PLURAL
	return "%d %s" % [saved_positive_count, unit]


func obtener_actual_partida_guardar_label() -> String:
	var total_runs: int = obtener_total_partidas()
	if total_runs <= 1:
		return ""
	return "Partida %d de %d" % [active_run_index, total_runs]


func _construir_estado_guardado_mecanica() -> Dictionary:
	var saved_item_entries: Array = []
	var placed_positive_item_ids: Array = []

	for runtime_item in level_items:
		var saved_item_entry: Dictionary = _construir_entrada_guardado_item(runtime_item)
		if saved_item_entry.is_empty():
			continue
		saved_item_entries.append(saved_item_entry)

		if bool(runtime_item.esPositivo) and plato.tiene_positivo_elemento(runtime_item):
			placed_positive_item_ids.append(str(runtime_item.save_instance_id))

	if saved_item_entries.is_empty():
		return {}

	return {
		"items": saved_item_entries,
		"placed_item_ids": placed_positive_item_ids
	}


func _construir_entrada_guardado_item(runtime_item: Node) -> Dictionary:
	if not is_instance_valid(runtime_item):
		return {}

	var item_path: String = str(runtime_item.item_resource_path).strip_edges()
	var instance_id: String = str(runtime_item.save_instance_id).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return {}

	return {
		"item_path": item_path,
		"instance_id": instance_id,
		"is_positive": bool(runtime_item.esPositivo)
	}


# --- Consultas de gameplay ----------------------------------------------------
func obtener_positivo_elementos_in_plato_cantidad() -> int:
	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE or not is_instance_valid(plato):
		return 0
	return plato.cantAlimentosPos.size()


func tiene_completado_actual_partida() -> bool:
	if not is_instance_valid(plato):
		return false
	if level_resource == null:
		return false
	return (
		int(level_resource.cantidadPositivos) == obtener_positivo_elementos_in_plato_cantidad()
		and plato.cantAlimentosNeg.is_empty()
	)


func filtrar_elementos_por_categoria(items: Array, category: String) -> Array:
	if category.strip_edges().is_empty():
		return items.duplicate()
	var wanted_category: String = GameTrackCatalog.normalizar_codigo_categoria(category)
	var filtered_items: Array = []
	for item in items:
		if GameTrackCatalog.categorias_coinciden(str(item.categoria), wanted_category):
			filtered_items.append(item)
	return filtered_items


# --- Runtime de items ---------------------------------------------------------
func generar_nivel_elemento(level_item: Resource, instance_id: String, is_positive: bool) -> Node:
	if level_item == null:
		push_warning("ManagerLevel: se intentó instanciar un elemento nulo.")
		return null
	if level_item.escena == null:
		push_warning("ManagerLevel: el elemento '%s' no tiene escena instanciable." % instance_id)
		return null
	var level_item_instance: Node = level_item.escena.instantiate()
	if level_item_instance == null:
		push_warning("ManagerLevel: falló la instanciación del elemento '%s'." % instance_id)
		return null
	level_item_instance.setup(level_item, plato, is_positive, instance_id)
	add_child(level_item_instance)
	level_items.append(level_item_instance)
	return level_item_instance


func limpiar_tiempo_ejecucion_elementos() -> void:
	for item in level_items:
		if is_instance_valid(item):
			item.queue_free()
	level_items.clear()
	if not is_instance_valid(plato):
		return
	plato.elementos.clear()
	plato.cantAlimentosPos.clear()
	plato.cantAlimentosNeg.clear()


func distribuir_tiempo_ejecucion_elementos() -> void:
	var next_item_position := Vector2(230, 680)
	var total_items: int = level_resource.cantidadNegativos + level_resource.cantidadPositivos
	if total_items < 5:
		next_item_position = Vector2(420, 680)
	for item in level_items:
		item.set_home_position(next_item_position)
		next_item_position.x += 120


# --- Carga de partida ---------------------------------------------------------
func _cargar_partida_actual(saved_level_state: Dictionary) -> void:
	limpiar_tiempo_ejecucion_elementos()

	if not _cargar_definicion_partida_actual():
		return

	_aplicar_activo_partida_carga()
	_configurar_nivel_recurso()

	var saved_mechanic_state: Dictionary = _extraer_estado_guardado_mecanica(saved_level_state)
	if _restaurar_partida_guardada(saved_mechanic_state):
		return

	_generar_frescos_elementos()
	level_items.shuffle()
	distribuir_tiempo_ejecucion_elementos()


func _cargar_definicion_partida_actual() -> bool:
	var level_number: int = Global.current_level
	active_run_data = Global.obtener_capitulo_partida_definicion(
		active_track_key,
		level_number,
		active_run_index
	)
	if active_run_data.is_empty():
		_resetear_estado_partida_activa()
		push_error(
			"ManagerLevel no encontro datos para %s capitulo %d partida %d."
			% [active_track_key, level_number, active_run_index]
		)
		return false

	active_mechanic_type = str(
		active_run_data.get("mechanic_type", PLATE_SORT_MECHANIC_TYPE)
	).strip_edges()
	if active_mechanic_type.is_empty():
		active_mechanic_type = PLATE_SORT_MECHANIC_TYPE

	if active_mechanic_type != PLATE_SORT_MECHANIC_TYPE:
		_resetear_estado_partida_activa()
		push_error("ManagerLevel no soporta la mecanica '%s'." % active_mechanic_type)
		return false

	return true


func _extraer_estado_guardado_mecanica(saved_level_state: Dictionary) -> Dictionary:
	var saved_mechanic_state: Dictionary = saved_level_state
	var raw_mechanic_state: Variant = saved_level_state.get("mechanic_state", null)
	if raw_mechanic_state is Dictionary and not (raw_mechanic_state as Dictionary).is_empty():
		saved_mechanic_state = raw_mechanic_state as Dictionary
	return saved_mechanic_state


func _restaurar_partida_guardada(saved_mechanic_state: Dictionary) -> bool:
	var saved_items: Array = _obtener_items_guardados(saved_mechanic_state)
	if not _intentar_restaurar_guardado_elementos(saved_items):
		return false

	distribuir_tiempo_ejecucion_elementos()
	_colocar_guardado_elementos_on_plato(saved_mechanic_state)
	return true


func _obtener_items_guardados(saved_mechanic_state: Dictionary) -> Array:
	var raw_saved_items: Variant = saved_mechanic_state.get("items", [])
	if raw_saved_items is Array:
		return raw_saved_items as Array
	return []


func _aplicar_activo_partida_carga() -> void:
	var run_payload: Dictionary = _obtener_payload_partida()
	if run_payload.is_empty():
		active_negative_item_count = int(active_run_data.get("negative_count", 0))
		active_positive_item_count = int(active_run_data.get("positive_count", 0))
		active_category_code = str(active_run_data.get("category", "")).strip_edges()
		_aplicar_configuracion_de_dificultad_arrastre()
		return

	active_negative_item_count = int(run_payload.get("negative_count", 0))
	active_positive_item_count = int(run_payload.get("positive_count", 0))
	active_category_code = str(run_payload.get("category", "")).strip_edges()
	_aplicar_configuracion_de_dificultad_arrastre()


func _obtener_payload_partida() -> Dictionary:
	var raw_payload: Variant = active_run_data.get("mechanic_payload", {})
	if raw_payload is Dictionary:
		return raw_payload as Dictionary
	return {}


func _configurar_nivel_recurso() -> void:
	level_resource.mechanic_type = active_mechanic_type
	level_resource.mechanic_payload = _construir_activo_partida_carga()
	level_resource.cantidadNegativos = active_negative_item_count
	level_resource.cantidadPositivos = active_positive_item_count
	level_resource.comida = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("meal_texture_path", "")
	)
	level_resource.condicion = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = GameChapterAssetCatalogScript.resolver_textura(
		active_run_data.get("teaching_texture_path", "")
	)
	meal_sprite.texture = level_resource.comida
	condition_sprite.texture = level_resource.condicion
	teaching_sprite.texture = level_resource.ensenanza
	_aplicar_ayuda_visual_de_arrastre()


func _conectar_escena_nodos(level_scene: Node) -> bool:
	if not is_instance_valid(plato):
		plato = level_scene.get_node_or_null("Plato")
	meal_sprite = level_scene.get_node_or_null("Globo texto/Meal") as Sprite2D
	condition_sprite = level_scene.get_node_or_null("Globo texto/Condition") as Sprite2D
	teaching_sprite = level_scene.get_node_or_null("Ensenanza") as Sprite2D

	var all_connected := (
		is_instance_valid(plato)
		and is_instance_valid(meal_sprite)
		and is_instance_valid(condition_sprite)
		and is_instance_valid(teaching_sprite)
	)
	if not all_connected:
		push_error(
			"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
		)
	return all_connected


# --- Generación y restauración de items --------------------------------------
func _generar_frescos_elementos() -> void:
	var item_pools: Dictionary = GameTrackItemPoolCatalogScript.construir_fondo_elemento_pista(
		active_track_key,
		level_resource.itemsPositivos,
		level_resource.itemsNegativos
	)

	_generar_items_desde_pool(
		item_pools.get("positive_items", []),
		active_positive_item_count,
		true,
		"positive"
	)
	_generar_items_desde_pool(
		item_pools.get("negative_items", []),
		active_negative_item_count,
		false,
		"negative"
	)


func _generar_items_desde_pool(
	source_items: Array,
	wanted_count: int,
	is_positive: bool,
	instance_prefix: String
) -> void:
	var filtered_items: Array = filtrar_elementos_por_categoria(source_items, active_category_code)
	filtered_items.shuffle()

	for item_index in range(wanted_count):
		if filtered_items.is_empty():
			break
		var level_item: Resource = filtered_items.pop_front()
		if level_item == null:
			continue
		generar_nivel_elemento(level_item, "%s_%d" % [instance_prefix, item_index], is_positive)


func _intentar_restaurar_guardado_elementos(saved_item_entries: Array) -> bool:
	if saved_item_entries.is_empty():
		return false

	for raw_saved_item in saved_item_entries:
		if _generar_guardado_elemento(raw_saved_item):
			continue
		limpiar_tiempo_ejecucion_elementos()
		return false

	return not level_items.is_empty()


func _colocar_guardado_elementos_on_plato(saved_mechanic_state: Dictionary) -> void:
	var raw_saved_positive_item_ids: Variant = saved_mechanic_state.get("placed_item_ids", [])
	if not raw_saved_positive_item_ids is Array:
		return

	var runtime_positive_items: Array = []
	for raw_item_id in raw_saved_positive_item_ids:
		var instance_id: String = str(raw_item_id).strip_edges()
		if instance_id.is_empty():
			continue

		var runtime_item = _buscar_tiempo_ejecucion_elemento_por_instance_id(instance_id)
		if runtime_item == null or not runtime_item.esPositivo:
			continue

		runtime_positive_items.append(runtime_item)

	for item_index in range(runtime_positive_items.size()):
		var runtime_item = runtime_positive_items[item_index]
		runtime_item.restore_to_plate(
			_obtener_plato_posicion(item_index, runtime_positive_items.size())
		)
		plato.restaurar_positivo_elemento(runtime_item)


func _generar_guardado_elemento(raw_saved_item: Variant) -> bool:
	if not raw_saved_item is Dictionary:
		return false

	var saved_item: Dictionary = raw_saved_item
	var item_path: String = str(saved_item.get("item_path", "")).strip_edges()
	var instance_id: String = str(saved_item.get("instance_id", "")).strip_edges()
	if item_path.is_empty() or instance_id.is_empty():
		return false

	var level_item = load(item_path)
	if level_item == null:
		return false

	var is_positive: bool = bool(saved_item.get("is_positive", false))
	return generar_nivel_elemento(level_item, instance_id, is_positive) != null


func _buscar_tiempo_ejecucion_elemento_por_instance_id(instance_id: String) -> Node:
	for runtime_item in level_items:
		if not is_instance_valid(runtime_item):
			continue
		if str(runtime_item.save_instance_id) == instance_id:
			return runtime_item
	return null


func _obtener_plato_posicion(index: int, total_items: int) -> Vector2:
	var columns: int = clampi(total_items, 1, MAX_PLATE_COLUMNS)
	var row: int = floori(float(index) / float(columns))
	var column: int = index % columns
	var horizontal_origin: float = float(columns - 1) / 2.0
	var offset: Vector2 = Vector2(
		(float(column) - horizontal_origin) * PLATE_ITEM_COLUMN_SPACING,
		float(row) * PLATE_ITEM_ROW_SPACING + PLATE_ITEM_VERTICAL_OFFSET
	)
	return plato.global_position + offset


# --- Helpers internos ---------------------------------------------------------
func _obtener_estado_guardado_actual() -> Dictionary:
	return Global.obtener_parcial_nivel_estado(active_track_key, Global.current_level)


func _resolver_indice_partida(saved_level_state: Dictionary) -> int:
	return clampi(
		int(saved_level_state.get("run_index", 1)),
		1,
		obtener_total_partidas()
	)


func _construir_activo_partida_carga() -> Dictionary:
	return {
		"negative_count": active_negative_item_count,
		"positive_count": active_positive_item_count,
		"category": active_category_code
	}


func _aplicar_configuracion_de_dificultad_arrastre() -> void:
	if _configuracion_dificultad_arrastre.is_empty():
		return
	active_positive_item_count = max(
		1,
		int(_configuracion_dificultad_arrastre.get("elementos_maximos", active_positive_item_count))
	)
	active_negative_item_count = max(
		0,
		int(
			_configuracion_dificultad_arrastre.get(
				"distractores_maximos",
				active_negative_item_count
			)
		)
	)


func _aplicar_ayuda_visual_de_arrastre() -> void:
	if not is_instance_valid(meal_sprite) or not is_instance_valid(condition_sprite):
		return
	meal_sprite.modulate = Color(1, 1, 1, 1)
	var mostrar_ayuda_visual: bool = bool(
		_configuracion_dificultad_arrastre.get("mostrar_ayuda_visual", true)
	)
	var opacidad_condicion: float = 1.0 if mostrar_ayuda_visual else 0.55
	condition_sprite.modulate = Color(1, 1, 1, opacidad_condicion)


func _resetear_estado_partida_activa() -> void:
	active_run_data = {}
	active_mechanic_type = ""
	_limpiar_activo_partida_carga()


func _limpiar_activo_partida_carga() -> void:
	active_positive_item_count = 0
	active_negative_item_count = 0
	active_category_code = ""


func _asegurar_recurso_nivel_cargado() -> void:
	if level_resource is Resource:
		return

	var resolved_resource_path: String = level_resource_path.strip_edges()
	if resolved_resource_path.is_empty():
		level_resource = LevelResourceScript.new()
		return

	var loaded_level_resource: Variant = load(resolved_resource_path)
	if loaded_level_resource is Resource:
		level_resource = loaded_level_resource
		return

	push_error(
		"ManagerLevel no pudo cargar level_resource en %s." % resolved_resource_path
	)
	level_resource = LevelResourceScript.new()
