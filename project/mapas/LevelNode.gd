extends Node2D

signal level_selected(scene_path)

@export var nivel_id: int
@export var escena: String
@export var desbloqueado: bool = false

const CLICK_RADIUS := 80.0

var base_scale := Vector2.ONE
var _hovered := false


func _ready():
	desbloqueado = LevelManager.esta_desbloqueado(nivel_id)


func _input(event: InputEvent) -> void:
	if not desbloqueado:
		return

	if event is InputEventMouseMotion:
		var inside := _is_inside(event.global_position)
		if inside and not _hovered:
			_hovered = true
			var tween := create_tween()
			tween.tween_property(self, "scale", base_scale * 1.08, 0.12)
		elif not inside and _hovered:
			_hovered = false
			var tween := create_tween()
			tween.tween_property(self, "scale", base_scale, 0.12)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_inside(event.global_position):
			_on_click()


func _on_click() -> void:
	if escena.is_empty():
		push_warning("LevelNode: no hay escena asignada para nivel %d" % nivel_id)
		return
	_bounce()
	await get_tree().create_timer(0.25).timeout
	level_selected.emit(escena)


func _is_inside(mouse_pos: Vector2) -> bool:
	return global_position.distance_to(mouse_pos) <= CLICK_RADIUS * scale.x


func setup(data: Dictionary, unlocked: bool) -> void:
	nivel_id = int(data.get("id", nivel_id))
	escena = str(data.get("scene", escena))
	desbloqueado = unlocked


func _bounce():
	var tween := create_tween()
	tween.tween_property(self, "scale", base_scale * Vector2(1.15, 0.90), 0.06)
	tween.tween_property(self, "scale", base_scale * Vector2(0.95, 1.05), 0.06)
	tween.tween_property(self, "scale", base_scale, 0.08)
