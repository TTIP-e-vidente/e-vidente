extends Node2D
class_name Libro

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DEFAULT_TRACK_KEY := "celiaquia"
const CHAPTER_BUTTON_DUPLICATE_FLAGS := 14
const CHAPTER_BUTTON_NAME_PREFIX := "Cap"

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var chapter_container: VBoxContainer = $VBoxContainer
@export var track_key_override := ""

var _chapter_button_icons: Array[Texture2D] = []
var _button_template: Button
var _active_track_key := ""


func _ready() -> void:
	_active_track_key = track_key_override.strip_edges()
	if _active_track_key.is_empty():
		_active_track_key = _get_track_key()
	if _active_track_key.is_empty():
		_active_track_key = DEFAULT_TRACK_KEY
	background_music.play()
	_load_button_template_from_scene()
	_rebuild_chapter_buttons()
	SaveManager.set_resume_to_book(_active_track_key)


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null
	_free_button_template()
	_chapter_button_icons.clear()


func _get_track_key() -> String:
	return ""


func _load_button_template_from_scene() -> void:
	if _button_template != null:
		return
	var chapter_buttons := _get_chapter_buttons()
	if chapter_buttons.is_empty():
		return
	_chapter_button_icons.clear()
	for chapter_button in chapter_buttons:
		if chapter_button.icon != null:
			_chapter_button_icons.append(chapter_button.icon)
	_button_template = (
		chapter_buttons[0].duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button
	)


func _rebuild_chapter_buttons() -> void:
	for chapter_button in _get_chapter_buttons():
		chapter_container.remove_child(chapter_button)
		chapter_button.free()
	if _button_template == null:
		return
	var level_count: int = max(1, Global.get_track_level_count(_active_track_key))
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
		chapter_button.disabled = not Global.is_level_unlocked(_active_track_key, level_number)
		chapter_button.pressed.connect(_on_chapter_button_pressed.bind(level_number))
		chapter_container.add_child(chapter_button)


func _free_button_template() -> void:
	if _button_template == null:
		return
	_button_template.free()
	_button_template = null


func _get_chapter_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if not _is_chapter_button(chapter_button):
			continue
		buttons.append(chapter_button)
	return buttons


func _is_chapter_button(chapter_button: Button) -> bool:
	return (
		chapter_button != null
		and chapter_button.name.begins_with(CHAPTER_BUTTON_NAME_PREFIX)
	)


func _on_chapter_button_pressed(level_number: int) -> void:
	GameSceneRouter.go_to_track_level(get_tree(), _active_track_key, level_number)


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_archivero(get_tree())
