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
var _chapter_button_blueprint: Button
var _active_track_key := ""


func _ready() -> void:
	_initialize_track_book_scene()


func _initialize_track_book_scene() -> void:
	_active_track_key = _resolve_book_track_key()
	_play_background_music()
	_capture_chapter_button_blueprint()
	_rebuild_track_chapter_buttons()
	_register_book_resume_target()
	_refresh_chapter_button_lock_state()



func _play_background_music() -> void:
	background_music.play()


func _register_book_resume_target() -> void:
	SaveManager.set_resume_to_book(_active_track_key)


func _resolve_configured_track_key() -> String:
	if not track_key_override.strip_edges().is_empty():
		return track_key_override.strip_edges()
	return DEFAULT_TRACK_KEY


func _resolve_book_track_key() -> String:
	return _resolve_configured_track_key().strip_edges()


func _refresh_chapter_button_lock_state() -> void:
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if not _is_generated_chapter_button(chapter_button):
			continue
		var level_number := _level_number_from_button_name(chapter_button.name)
		chapter_button.disabled = not Global.is_level_unlocked(_active_track_key, level_number)


func _capture_chapter_button_blueprint() -> void:
	if _chapter_button_blueprint != null:
		return
	var existing_buttons := _find_existing_chapter_buttons()
	if existing_buttons.is_empty():
		return
	_chapter_button_icons.clear()
	for chapter_button in existing_buttons:
		if chapter_button.icon != null:
			_chapter_button_icons.append(chapter_button.icon)
	_chapter_button_blueprint = (
		existing_buttons[0].duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button
	)


func _rebuild_track_chapter_buttons() -> void:
	_clear_existing_chapter_buttons()
	if _chapter_button_blueprint == null:
		return
	var level_count: int = max(1, Global.get_track_level_count(_active_track_key))
	for level_number in range(1, level_count + 1):
		var chapter_button := _build_chapter_button_instance()
		if chapter_button == null:
			continue
		_configure_chapter_button_for_level(chapter_button, level_number)
		chapter_container.add_child(chapter_button)


func _clear_existing_chapter_buttons() -> void:
	for chapter_button in _find_existing_chapter_buttons():
		chapter_container.remove_child(chapter_button)
		chapter_button.queue_free()


func _build_chapter_button_instance() -> Button:
	if _chapter_button_blueprint == null:
		return null
	return _chapter_button_blueprint.duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button


func _configure_chapter_button_for_level(
	chapter_button: Button,
	level_number: int
) -> void:
	chapter_button.name = "%s%d" % [CHAPTER_BUTTON_NAME_PREFIX, level_number]
	chapter_button.tooltip_text = "Abrir capitulo %d" % level_number
	_apply_chapter_button_visuals(chapter_button, level_number)
	chapter_button.pressed.connect(_on_generated_chapter_button_pressed.bind(level_number))


func _apply_chapter_button_visuals(chapter_button: Button, level_number: int) -> void:
	if level_number - 1 < _chapter_button_icons.size():
		chapter_button.icon = _chapter_button_icons[level_number - 1]
		chapter_button.text = ""
		return
	chapter_button.icon = null
	chapter_button.text = "Capitulo %d" % level_number


func _find_existing_chapter_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if not _is_generated_chapter_button(chapter_button):
			continue
		buttons.append(chapter_button)
	return buttons


func _is_generated_chapter_button(chapter_button: Button) -> bool:
	return (
		chapter_button != null
		and chapter_button.name.begins_with(CHAPTER_BUTTON_NAME_PREFIX)
	)


func _level_number_from_button_name(button_name: String) -> int:
	return int(button_name.trim_prefix(CHAPTER_BUTTON_NAME_PREFIX))


func _on_generated_chapter_button_pressed(level_number: int) -> void:
	_open_track_chapter(level_number)


func _open_track_chapter(level_number: int) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		_active_track_key,
		level_number
	)


func _return_to_archivero() -> void:
	GameSceneRouter.go_to_archivero(get_tree())


func _on_atras_pressed() -> void:
	_return_to_archivero()
