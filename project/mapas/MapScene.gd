extends Node2D

@export var map_data: MapData
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const STREAK_SEAL_SCENE := preload("res://interface/components/StreakDailySeal.tscn")
const PROFILE_BUTTON_SCRIPT := preload("res://interface/components/ProfileProgressButton.gd")

var level_node_scene := preload("res://mapas/LevelNode.tscn")

@onready var btn_atras: Button = $"Atrás"
@onready var nodes_container = $NodesContainer

var escala_original := Vector2.ONE


func _ready():
	escala_original = btn_atras.scale
	btn_atras.mouse_entered.connect(_on_back_hover)
	btn_atras.mouse_exited.connect(_on_back_exit)
	_build_hud()
	_render_map()


func _on_back_hover():
	var tween = create_tween()
	var t = tween.tween_property(btn_atras, "scale", escala_original * 1.04, 0.12)
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)


func _on_back_exit():
	var tween = create_tween()
	var t = tween.tween_property(btn_atras, "scale", escala_original, 0.12)
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)


func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 75
	add_child(hud_layer)

	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	var streak_seal := STREAK_SEAL_SCENE.instantiate() as Control
	if streak_seal != null:
		streak_seal.anchor_left = 0.0
		streak_seal.anchor_top = 0.0
		streak_seal.anchor_right = 0.0
		streak_seal.anchor_bottom = 0.0
		streak_seal.offset_left = 16.0
		streak_seal.offset_top = 16.0
		streak_seal.offset_right = 152.0
		streak_seal.offset_bottom = 152.0
		hud_root.add_child(streak_seal)

	var profile_btn := Button.new()
	profile_btn.script = PROFILE_BUTTON_SCRIPT
	profile_btn.anchor_left = 1.0
	profile_btn.anchor_top = 0.0
	profile_btn.anchor_right = 1.0
	profile_btn.anchor_bottom = 0.0
	profile_btn.offset_left = -152.0
	profile_btn.offset_top = 16.0
	profile_btn.offset_right = -16.0
	profile_btn.offset_bottom = 84.0
	profile_btn.tooltip_text = "Mi progreso"
	profile_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(profile_btn)


func _render_map() -> void:
	if map_data == null:
		return

	for level_data in map_data.levels:
		var node = level_node_scene.instantiate()
		nodes_container.add_child(node)

		node.position = level_data.pos

		var unlocked := _is_level_unlocked(level_data.id)
		node.setup(level_data, unlocked)

		node.level_selected.connect(_on_level_selected)


func _on_level_selected(scene_path: String):
	get_tree().change_scene_to_file(scene_path)


func _is_level_unlocked(id: int) -> bool:
	if id == 1:
		return true
	return id <= Global.current_level


func _on_atrás_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
