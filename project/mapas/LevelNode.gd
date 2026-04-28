@tool
extends Node2D

signal node_selected(selected_target: Variant)

const MapNodeDataScript := preload("res://mapas/MapNodeData.gd")
const NODE_KIND_CHAPTER := "chapter"
const NODE_KIND_QUESTION := "question"
const COLOR_COMPLETADO := Color("#db9d4b")
const COLOR_BLOQUEADO := Color(1, 1, 1, 0.35)

@export_group("Estado en Partida")
@export var nivel_id: int = 0
@export var desbloqueado: bool = false

@export_group("Destino")
@export_enum("chapter", "question") var node_kind: String = NODE_KIND_CHAPTER:
	set(value):
		_tipo_nodo_configurado = _normalizar_tipo_nodo(value)
		_actualizar_preview_en_editor()
	get:
		return _tipo_nodo_configurado
@export var track_key: String = "celiaquia"
@export var level_number: int = 0
@export var question_number: int = 0
@export var node_key: String = ""

@export_group("Destino Nodo Jugable - Avanzado")
@export_file("*.json") var node_json_path: String = ""
@export_file("*.tres") var node_resource_path: String = ""

@export_group("Vista en Editor")
@export var label_text: String = "Nodo":
	set(value):
		_texto_label_configurado = value.strip_edges()
		_actualizar_preview_en_editor()
	get:
		return _texto_label_configurado
@export var icon_texture: Texture2D:
	set(value):
		_textura_icono_configurada = value
		_actualizar_preview_en_editor()
	get:
		return _textura_icono_configurada

var escala_base: Vector2 = Vector2.ONE
var _esta_hover: bool = false
var _esta_completado: bool = false
var _datos_nodo_runtime: RefCounted = null
var _click_en_curso: bool = false

var _tipo_nodo_configurado: String = NODE_KIND_CHAPTER
var _texto_label_configurado: String = "Nodo"
var _textura_icono_configurada: Texture2D = null

@onready var boton: TextureButton = $Button
@onready var icono: Sprite2D = $Icon


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	escala_base = scale
	_actualizar_vista_nodo()


# Escena -> contrato ---------------------------------------------------------
func crear_datos_runtime_nodo() -> RefCounted:
	var node_data: RefCounted = MapNodeDataScript.crear()
	node_data.node_id = nivel_id
	node_data.node_kind = _tipo_nodo_configurado
	node_data.label_text = _resolver_texto_label()
	node_data.track_key = track_key.strip_edges()
	node_data.level_number = level_number
	node_data.question_number = question_number
	node_data.node_key = node_key.strip_edges()
	node_data.node_json_path = node_json_path.strip_edges()
	node_data.node_resource_path = node_resource_path.strip_edges()
	node_data.icon_texture_path = _resolver_ruta_icono()
	node_data.node_position = position
	return node_data


# TODO post-demo: eliminar cuando no haya escenas usando question_*.
func _set(property: StringName, value: Variant) -> bool:
	match String(property):
		"question_key":
			node_key = str(value).strip_edges()
			return true
		"question_json_path":
			node_json_path = str(value).strip_edges()
			return true
		"question_resource_path":
			node_resource_path = str(value).strip_edges()
			return true
	return false


func _get(property: StringName) -> Variant:
	match String(property):
		"question_key":
			return node_key
		"question_json_path":
			return node_json_path
		"question_resource_path":
			return node_resource_path
	return null


func aplicar_estado_nodo(node_data: RefCounted, unlocked: bool, completed: bool = false) -> void:
	desbloqueado = unlocked
	_esta_completado = completed
	_datos_nodo_runtime = node_data.duplicar_datos()
	position = node_data.node_position
	_actualizar_vista_nodo()


# Interaccion ----------------------------------------------------------------
func _on_button_pressed() -> void:
	if _click_en_curso or Engine.is_editor_hint():
		return

	var datos_nodo_actual: RefCounted = _obtener_datos_nodo_actual()
	if datos_nodo_actual == null or not datos_nodo_actual.tiene_destino_runtime():
		push_warning("LevelNode: no hay destino asignado para el nodo %d" % nivel_id)
		return

	_click_en_curso = true
	_animar_click()
	await get_tree().create_timer(0.25).timeout
	node_selected.emit(datos_nodo_actual)
	_click_en_curso = false


func _on_button_mouse_entered() -> void:
	if boton.disabled or _esta_hover or Engine.is_editor_hint():
		return
	_esta_hover = true
	_animar_escala_hasta(escala_base * 1.08)


func _on_button_mouse_exited() -> void:
	if not _esta_hover or Engine.is_editor_hint():
		return
	_esta_hover = false
	_animar_escala_hasta(escala_base)


func _animar_escala_hasta(target_scale: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12)


func _animar_click() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", escala_base * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", escala_base * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", escala_base, 0.08)


func _aplicar_estado_interaccion() -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		boton.disabled = false
		boton.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	boton.disabled = not desbloqueado or _esta_completado
	boton.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW
		if boton.disabled
		else Control.CURSOR_POINTING_HAND
	)


# Visual ---------------------------------------------------------------------
func _actualizar_preview_en_editor() -> void:
	if not is_node_ready() or not Engine.is_editor_hint():
		return
	_actualizar_vista_nodo()


func _actualizar_vista_nodo() -> void:
	if not is_node_ready():
		return

	var datos_nodo_actual: RefCounted = _obtener_datos_nodo_actual()
	icono.texture = _resolver_textura_icono(datos_nodo_actual)
	_aplicar_estado_interaccion()
	_aplicar_color_por_progreso()


func _aplicar_color_por_progreso() -> void:
	if Engine.is_editor_hint():
		modulate = Color.WHITE
		return
	if _esta_completado:
		modulate = COLOR_COMPLETADO
	elif not desbloqueado:
		modulate = COLOR_BLOQUEADO
	else:
		modulate = Color.WHITE


func _obtener_datos_nodo_actual() -> RefCounted:
	if _datos_nodo_runtime != null:
		return _datos_nodo_runtime
	return crear_datos_runtime_nodo()


func _resolver_textura_icono(node_data: RefCounted) -> Texture2D:
	if node_data != null:
		var ruta_icono_runtime: String = str(node_data.icon_texture_path).strip_edges()
		var textura_icono_runtime: Texture2D = _cargar_textura_desde_ruta(ruta_icono_runtime)
		if textura_icono_runtime != null:
			return textura_icono_runtime
	return _textura_icono_configurada


func _resolver_texto_label() -> String:
	if not _texto_label_configurado.is_empty():
		return _texto_label_configurado
	if _tipo_nodo_configurado == NODE_KIND_QUESTION:
		return "Pregunta %d" % max(1, question_number if question_number > 0 else nivel_id)
	return "Receta %d" % max(1, level_number if level_number > 0 else nivel_id)


func _resolver_ruta_icono() -> String:
	if _textura_icono_configurada == null:
		return ""
	return str(_textura_icono_configurada.resource_path).strip_edges()


func _cargar_textura_desde_ruta(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	var texture_resource: Variant = load(texture_path)
	if texture_resource is Texture2D:
		return texture_resource
	return null


func _normalizar_tipo_nodo(value: String) -> String:
	return (
		NODE_KIND_QUESTION
		if value.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)
