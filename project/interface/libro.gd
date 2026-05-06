extends Node2D
class_name Libro

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_TRACK_KEY := "celiaquia"
const CHAPTER_BUTTON_DUPLICATE_FLAGS := 14
const CHAPTER_BUTTON_NAME_PREFIX := "Cap"
const HOVER_SCALE := 1.06
const HOVER_DURATION := 0.12
const MUSICA_FONDO_PREDETERMINADA := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var chapter_container: VBoxContainer = $VBoxContainer
@export var track_key_override := ""
@onready var titulo_nivel: Label = $TituloNivel/Label


	
var _chapter_button_icons: Array[Texture2D] = []
var _button_template: Button
var _active_track_key := ""
var _chapter_hover_tweens: Dictionary = {}


func _ready() -> void:
	titulo_nivel.text = "Celiaquía"
	_active_track_key = track_key_override.strip_edges()
	if _active_track_key.is_empty():
		_active_track_key = _obtener_clave_pista()
	if _active_track_key.is_empty():
		_active_track_key = DEFAULT_TRACK_KEY
	MusicManager.reproducir_musica(MUSICA_FONDO_PREDETERMINADA)
	_cargar_plantilla_boton_desde_escena()
	_reconstruir_botones_capitulo()
	SaveManager.establecer_reanudar_en_libro(_active_track_key)


func _exit_tree() -> void:
	if _button_template != null:
		_button_template.free()
		_button_template = null
	_chapter_button_icons.clear()


func _obtener_clave_pista() -> String:
	return ""


func _cargar_plantilla_boton_desde_escena() -> void:
	if _button_template != null:
		return
	var chapter_buttons := _obtener_botones_capitulo()
	if chapter_buttons.is_empty():
		return
	_chapter_button_icons.clear()
	for chapter_button in chapter_buttons:
		if chapter_button.icon != null:
			_chapter_button_icons.append(chapter_button.icon)
	_button_template = (
		chapter_buttons[0].duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button
	)


func _reconstruir_botones_capitulo() -> void:
	for chapter_button in _obtener_botones_capitulo():
		chapter_container.remove_child(chapter_button)
		chapter_button.free()
	if _button_template == null:
		return
	var level_count: int = max(1, Global.obtener_pista_nivel_cantidad(_active_track_key))
	for level_number in range(1, level_count + 1):
		var chapter_button := (
			_button_template.duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button
		)
		if chapter_button == null:
			continue
		chapter_button.name = "%s%d" % [CHAPTER_BUTTON_NAME_PREFIX, level_number]
		chapter_button.tooltip_text = "Abrir capitulo %d" % level_number
		if level_number - 1 < _chapter_button_icons.size():
			chapter_button.icon = _chapter_button_icons[level_number - 1]
			chapter_button.text = ""
		else:
			chapter_button.icon = null
			chapter_button.text = "Capitulo %d" % level_number
		chapter_button.disabled = not Global.es_nivel_desbloqueado(_active_track_key, level_number)
		chapter_button.pressed.connect(_on_boton_capitulo_presionado.bind(level_number))
		chapter_button.mouse_entered.connect(_on_hover_capitulo.bind(chapter_button, true))
		chapter_button.mouse_exited.connect(_on_hover_capitulo.bind(chapter_button, false))
		chapter_container.add_child(chapter_button)


func _obtener_botones_capitulo() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if chapter_button == null or not chapter_button.name.begins_with(CHAPTER_BUTTON_NAME_PREFIX):
			continue
		buttons.append(chapter_button)
	return buttons


func _on_boton_capitulo_presionado(level_number: int) -> void:
	GameSceneRouter.go_to_track_level(get_tree(), _active_track_key, level_number)


func _on_hover_capitulo(button: Button, entered: bool) -> void:
	if button.disabled:
		return
	var target_scale := Vector2(HOVER_SCALE, HOVER_SCALE) if entered else Vector2.ONE
	if _chapter_hover_tweens.has(button) and is_instance_valid(_chapter_hover_tweens[button]):
		_chapter_hover_tweens[button].kill()
	var tw := create_tween()
	tw.tween_property(button, "scale", target_scale, HOVER_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chapter_hover_tweens[button] = tw


func _on_atras_presionado() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
