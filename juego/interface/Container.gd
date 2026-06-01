extends Container
class_name ArchiveroTrackItem

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")

@onready var anim: AnimationPlayer = $Anim
@onready var archive_sprite: Sprite2D = $"Archivero-Celiaco"

@export var file: String = ""

var archive_highlighted := false
var track_key := ""


func configurar(track_definition: Dictionary) -> void:
	track_key = str(track_definition.get("key", "")).strip_edges()
	file = str(track_definition.get("book_scene_path", file)).strip_edges()
	var _track_label := str(track_definition.get("label", "")).strip_edges()
	var texture_path := str(track_definition.get("archive_texture_path", "")).strip_edges()
	if not texture_path.is_empty():
		archive_sprite.texture = load(texture_path) as Texture2D
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _on_mouse_entrado() -> void:
	anim.play("select")
	archive_highlighted = true


func _on_mouse_salido() -> void:
	anim.play("deselect")
	archive_highlighted = false


func _on_entrada_gui(event: InputEvent) -> void:
	if not archive_highlighted:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not track_key.is_empty() and GameTrackCatalog.tiene_pista(track_key):
		GameSceneRouter.go_to_track_book(get_tree(), track_key)
		return
	if not file.is_empty():
		get_tree().change_scene_to_file(file)
