@tool
extends Node2D

signal nodo_seleccionado(datos_mapa_nodo: RefCounted)

const MapNodeDataScript := preload("res://mapas/core/MapNodeData.gd")
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
var esta_completado: bool = false
var _datos_nodo_runtime: RefCounted = null
var _click_en_curso: bool = false

var _tipo_nodo_configurado: String = NODE_KIND_CHAPTER
var _texto_label_configurado: String = "Nodo"
var _textura_icono_configurada: Texture2D = null

@onready var boton_nodo: TextureButton = $Button
@onready var icono_estado: Sprite2D = $Icon


# Ciclo de vida ---------------------------------------------------------------
func _ready() -> void:
	escala_base = scale
	actualizar_estado_visual()


# Escena -> contrato ---------------------------------------------------------
func crear_datos_runtime_nodo() -> RefCounted:
	var datos_mapa_nodo: RefCounted = MapNodeDataScript.crear()
	datos_mapa_nodo.node_id = nivel_id
	datos_mapa_nodo.node_kind = _tipo_nodo_configurado
	datos_mapa_nodo.label_text = _resolver_texto_label()
	datos_mapa_nodo.track_key = track_key.strip_edges()
	datos_mapa_nodo.level_number = level_number
	datos_mapa_nodo.question_number = question_number
	datos_mapa_nodo.node_key = node_key.strip_edges()
	datos_mapa_nodo.node_json_path = node_json_path.strip_edges()
	datos_mapa_nodo.node_resource_path = node_resource_path.strip_edges()
	datos_mapa_nodo.icon_texture_path = _resolver_ruta_icono()
	datos_mapa_nodo.node_position = position
	return datos_mapa_nodo


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


func configurar(
	datos_mapa_nodo: RefCounted,
	esta_disponible: bool,
	completado_nuevo: bool = false
) -> void:
	desbloqueado = esta_disponible
	esta_completado = completado_nuevo
	_datos_nodo_runtime = datos_mapa_nodo.duplicar_datos()
	position = datos_mapa_nodo.node_position
	actualizar_estado_visual()


# Interaccion ----------------------------------------------------------------
func _on_button_pressed() -> void:
	if _click_en_curso or Engine.is_editor_hint():
		return

	var datos_nodo_actual: RefCounted = _obtener_datos_nodo_actual()
	if datos_nodo_actual == null or not datos_nodo_actual.esta_disponible():
		push_warning("LevelNode: no hay destino asignado para el nodo %d" % nivel_id)
		return

	_click_en_curso = true
	_animar_click()
	await get_tree().create_timer(0.25).timeout
	nodo_seleccionado.emit(datos_nodo_actual)
	_click_en_curso = false


func _on_button_mouse_entered() -> void:
	if boton_nodo.disabled or _esta_hover or Engine.is_editor_hint():
		return
	_esta_hover = true
	_animar_escala_hasta(escala_base * 1.08)


func _on_button_mouse_exited() -> void:
	if not _esta_hover or Engine.is_editor_hint():
		return
	_esta_hover = false
	_animar_escala_hasta(escala_base)


func _animar_escala_hasta(escala_destino: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", escala_destino, 0.12)


func _animar_click() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", escala_base * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", escala_base * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", escala_base, 0.08)


func _aplicar_estado_interaccion() -> void:
	if not is_node_ready():
		return
	if Engine.is_editor_hint():
		boton_nodo.disabled = false
		boton_nodo.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return

	boton_nodo.disabled = not desbloqueado or esta_completado
	boton_nodo.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW
		if boton_nodo.disabled
		else Control.CURSOR_POINTING_HAND
	)


# Visual ---------------------------------------------------------------------
func _actualizar_preview_en_editor() -> void:
	if not is_node_ready() or not Engine.is_editor_hint():
		return
	actualizar_estado_visual()


func actualizar_estado_visual() -> void:
	if not is_node_ready():
		return

	var datos_nodo_actual: RefCounted = _obtener_datos_nodo_actual()
	icono_estado.texture = _resolver_textura_icono(datos_nodo_actual)
	_aplicar_estado_interaccion()
	_aplicar_estado_visual()


func _aplicar_estado_visual() -> void:
	if Engine.is_editor_hint():
		mostrar_disponible()
		return
	if esta_completado:
		mostrar_completado()
		return
	if not desbloqueado:
		mostrar_bloqueado()
		return
	mostrar_disponible()


func mostrar_bloqueado() -> void:
	modulate = COLOR_BLOQUEADO


func mostrar_disponible() -> void:
	modulate = Color.WHITE


func mostrar_completado() -> void:
	modulate = COLOR_COMPLETADO


func _obtener_datos_nodo_actual() -> RefCounted:
	if _datos_nodo_runtime != null:
		return _datos_nodo_runtime
	return crear_datos_runtime_nodo()


func _resolver_textura_icono(datos_mapa_nodo: RefCounted) -> Texture2D:
	if datos_mapa_nodo != null:
		var ruta_icono_runtime: String = str(datos_mapa_nodo.icon_texture_path).strip_edges()
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


func _cargar_textura_desde_ruta(ruta_textura: String) -> Texture2D:
	if ruta_textura.is_empty():
		return null
	var recurso_textura: Variant = load(ruta_textura)
	if recurso_textura is Texture2D:
		return recurso_textura
	return null


func _normalizar_tipo_nodo(valor: String) -> String:
	return (
		NODE_KIND_QUESTION
		if valor.strip_edges().to_lower() == NODE_KIND_QUESTION
		else NODE_KIND_CHAPTER
	)
