extends Node2D

signal level_selected(scene_path)


@onready var icon: Sprite2D = $Button/Icon
@onready var button: TextureButton = $Button


var data
var unlocked := false


func setup(level_data: Dictionary, is_unlocked: bool) -> void:
	data = level_data
	unlocked = is_unlocked

	_update_visual()


func _update_visual() -> void:
	button.disabled = not unlocked

	if unlocked:
		modulate = Color(1,1,1,1)
	else:
		modulate = Color(1.3,1.3,1.3,1)


func _ready():
	button.pressed.connect(_on_pressed)
	button.mouse_entered.connect(_on_hover)
	button.mouse_exited.connect(_on_exit)


func _on_pressed():
	if not unlocked:
		return

	emit_signal("level_selected", data.scene)


func _on_hover():
	if not unlocked:
		return

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1,1.1), 0.15)


func _on_exit():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1,1), 0.15)
