extends Node2D

signal level_selected(scene_path)

@export var nivel_id: int
@export var escena: String

@onready var icon: Sprite2D = $Button/Icon
@onready var button: TextureButton = $Button

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

func setup(data: Dictionary, unlocked: bool) -> void:
	nivel_id = int(data.get("id", nivel_id))
	escena = str(data.get("scene", escena))
	desbloqueado = unlocked

func _click():
	if not desbloqueado:
		return
	if escena.is_empty():
		push_warning("LevelNode: no hay escena asignada para nivel %d" % nivel_id)
		return
	
	_bounce()
	await get_tree().create_timer(0.2).timeout
	
	level_selected.emit(escena)

func _bounce():
	var tween = create_tween()
	tween.tween_property(self, "scale", base_scale * Vector2(1.03, 0.97), 0.05)
	tween.tween_property(self, "scale", base_scale * Vector2(0.99, 1.01), 0.05)
	tween.tween_property(self, "scale", base_scale, 0.06)
