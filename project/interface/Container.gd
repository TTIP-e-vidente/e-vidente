extends Container
class_name ARCHIVERO_NIVELES

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var anim: AnimationPlayer = $Anim
@onready var archive_sprite: Sprite2D = $"Archivero-Celiaco"

@export var file: String = ""

var archive_highlighted := false
var track_key := ""


func configure(track_definition: Dictionary) -> void:
	track_key = str(track_definition.get("key", "")).strip_edges()
	file = str(track_definition.get("book_scene_path", file)).strip_edges()
	var track_label := str(track_definition.get("label", "")).strip_edges()
	var texture_path := str(track_definition.get("archive_texture_path", "")).strip_edges()
	if not texture_path.is_empty():
		archive_sprite.texture = load(texture_path) as Texture2D
	tooltip_text = "Abrir %s" % (track_label if not track_label.is_empty() else "modo")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_mouse_entered() -> void:
	anim.play("select")
	archive_highlighted = true


func _on_mouse_exited() -> void:
	anim.play("deselect")
	archive_highlighted = false


func _on_gui_input(event: InputEvent) -> void:
	if not archive_highlighted:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_track_book()


func _open_track_book() -> void:
	if not track_key.is_empty() and Global.has_track(track_key):
		GameSceneRouter.go_to_track_book(get_tree(), track_key)
		return
	if not file.is_empty():
		get_tree().change_scene_to_file(file)
