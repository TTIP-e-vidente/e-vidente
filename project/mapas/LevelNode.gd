extends Node2D

signal level_selected(scene_path)

@export var nivel_id: int
@export var escena: String

@onready var sprite: Sprite2D = $Sprite2D
@onready var icon: Sprite2D = $Button/Icon
@onready var button: TextureButton = $Button
@onready var collision_shape_2d: CollisionShape2D = $Sprite/CollisionShape2D

@export var desbloqueado: bool = false

var base_scale := Vector2.ONE

func _ready():
	desbloqueado = LevelManager.esta_desbloqueado(nivel_id)

	button.mouse_entered.connect(_mouse_enter)
	button.mouse_exited.connect(_mouse_exit)
	button.pressed.connect(_click)

func _mouse_enter():
	if desbloqueado:
		var tween = create_tween()
		tween.tween_property(self, "scale", base_scale * 1.05, 0.1)

func _mouse_exit():
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale, 0.1)

func _click():
	if not desbloqueado:
		return
	
	_bounce()
	await get_tree().create_timer(0.2).timeout
	
	level_selected.emit("res://niveles/nivel_1/Level.tscn")

func _bounce():
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * Vector2(1.03, 0.97), 0.05)
	tween.tween_property(self, "scale", base_scale * Vector2(0.99, 1.01), 0.05)
	tween.tween_property(self, "scale", base_scale, 0.06)
