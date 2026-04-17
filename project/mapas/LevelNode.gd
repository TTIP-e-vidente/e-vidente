extends Node2D

signal level_selected(scene_path)


@onready var icon: Sprite2D = $Icon
@onready var icon_2: Sprite2D = $VBoxContainer/Button2/Icon2
@onready var icon_3: Sprite2D = $VBoxContainer/Button3/Icon3
@onready var icon_4: Sprite2D = $VBoxContainer/Button4/Icon4
@onready var icon_5: Sprite2D = $VBoxContainer/Button5/Icon5
@onready var icon_6: Sprite2D = $VBoxContainer/Button6/Icon6
@onready var icon_7: Sprite2D = $VBoxContainer/Button7/Icon7
@onready var icon_8: Sprite2D = $VBoxContainer/Button8/Icon8
@onready var button: TextureButton = $Button
@onready var button_2: TextureButton = $VBoxContainer/Button
@onready var button_3: TextureButton = $VBoxContainer/Button3
@onready var button_4: TextureButton = $VBoxContainer/Button4
@onready var button_5: TextureButton = $VBoxContainer/Button5
@onready var button_6: TextureButton = $VBoxContainer/Button6
@onready var button_7: TextureButton = $VBoxContainer/Button7
@onready var button_8: TextureButton = $VBoxContainer/Button8

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
