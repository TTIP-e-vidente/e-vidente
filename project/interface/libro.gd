extends Node2D
class_name Libro

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const CHAPTER_BUTTON_DUPLICATE_FLAGS := 14

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var chapter_container: VBoxContainer = $VBoxContainer
@export var track_key_override := ""

var _chapter_button_icons: Array[Texture2D] = []
var _chapter_button_template: Button


func _ready() -> void:
	_initialize_track_book_scene()


func _initialize_track_book_scene() -> void:
	background_music.play()
	_capture_chapter_button_blueprint()
	_rebuild_track_chapter_buttons()
	SaveManager.set_resume_to_book(_resolve_book_track_key())
	_refresh_chapter_button_lock_state()


func _get_track_key() -> String:
	if not track_key_override.strip_edges().is_empty():
		return track_key_override.strip_edges()
	return "celiaquia"


func _resolve_book_track_key() -> String:
	return _get_track_key().strip_edges()


func _refresh_chapter_button_lock_state() -> void:
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if chapter_button == null or not chapter_button.name.begins_with("Cap"):
			continue
		var level_number := int(chapter_button.name.trim_prefix("Cap"))
		chapter_button.disabled = not Global.is_level_unlocked(
			_resolve_book_track_key(),
			level_number
		)


func _capture_chapter_button_blueprint() -> void:
	if _chapter_button_template != null:
		return
	var existing_buttons := _find_existing_chapter_buttons()
	if existing_buttons.is_empty():
		return
	_chapter_button_icons.clear()
	for chapter_button in existing_buttons:
		if chapter_button.icon != null:
			_chapter_button_icons.append(chapter_button.icon)
	_chapter_button_template = existing_buttons[0].duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button


func _rebuild_track_chapter_buttons() -> void:
	var existing_buttons := _find_existing_chapter_buttons()
	for chapter_button in existing_buttons:
		chapter_container.remove_child(chapter_button)
		chapter_button.queue_free()
	if _chapter_button_template == null:
		return
	var level_count: int = max(1, Global.get_track_level_count(_resolve_book_track_key()))
	for level_number in range(1, level_count + 1):
		var chapter_button := _chapter_button_template.duplicate(CHAPTER_BUTTON_DUPLICATE_FLAGS) as Button
		if chapter_button == null:
			continue
		_configure_chapter_button_for_level(chapter_button, level_number)
		chapter_container.add_child(chapter_button)


func _configure_chapter_button_for_level(
	chapter_button: Button,
	level_number: int
) -> void:
	chapter_button.name = "Cap%d" % level_number
	chapter_button.tooltip_text = "Abrir capitulo %d" % level_number
	if level_number - 1 < _chapter_button_icons.size():
		chapter_button.icon = _chapter_button_icons[level_number - 1]
		chapter_button.text = ""
	else:
		chapter_button.icon = null
		chapter_button.text = "Capitulo %d" % level_number
	chapter_button.pressed.connect(_on_generated_chapter_button_pressed.bind(level_number))


func _find_existing_chapter_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in chapter_container.get_children():
		var chapter_button := child as Button
		if chapter_button == null or not chapter_button.name.begins_with("Cap"):
			continue
		buttons.append(chapter_button)
	return buttons


func _on_generated_chapter_button_pressed(level_number: int) -> void:
	_open_track_chapter(level_number)


func _open_track_chapter(level_number: int) -> void:
	GameSceneRouter.go_to_track_level(
		get_tree(),
		_resolve_book_track_key(),
		level_number
	)


func _return_to_archivero() -> void:
	GameSceneRouter.go_to_archivero(get_tree())


func _on_atras_pressed() -> void:
	_return_to_archivero()
