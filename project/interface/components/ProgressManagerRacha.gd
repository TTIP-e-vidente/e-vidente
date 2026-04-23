extends Control

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const DayCircleScript := preload("res://interface/components/DayCircle.gd")
const FORWARD_ARROW_TEXTURE := preload(
	"res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias.png"
)
const EMPTY_STREAK_BAR_TEXTURE := preload(
	"res://assets-sistema/racha-diaria/barra-dias-incompletos.png"
)
const FULL_STREAK_BAR_TEXTURE := preload(
	"res://assets-sistema/racha-diaria/barra-dias.png"
)
const DEFAULT_TITLE := "Racha Diaria"
const DEFAULT_RETURN_SCENE := "res://mapas/MapScene.tscn"
const STREAK_RETURN_SCENE_META := "streak_return_scene"
const STREAK_FEEDBACK_META := "streak_feedback"
const STREAK_CONTINUE_TARGET_META := "streak_continue_target"
const STATUS_MESSAGE_ACTIVATED := "Hoy activaste la racha, segui asi."
const STATUS_MESSAGE_SUSTAINED := "Hoy sostuviste la racha."
const TRACK_FILL_COLOR := Color(0.876, 0.643, 0.259, 0.98)
const TRACK_DOT_FUTURE_COLOR := Color(0.985, 0.985, 0.985, 1.0)
const TRACK_DOT_ACTIVE_COLOR := Color(0.972, 0.857, 0.608, 1.0)
const TRACK_DOT_CURRENT_COLOR := Color(0.936, 0.718, 0.302, 1.0)
const MAX_VISIBLE_DAYS := 7

var _current_count: int = 0
var _best_count: int = 0
var _status_key: String = "inactive"
var _status_detail: String = ""
var _day_circles: Array[Node] = []
var _connector_sprites: Array[Sprite2D] = []
var _progress_dot_nodes: Array[Panel] = []
var _progress_dot_centers: Array[Vector2] = []
var _detail_label: Label
var _progress_overlay: Control
var _progress_fill: Panel
var _continue_button: Button
var _feedback_continue_target: Dictionary = {}
var _pulse_tween: Tween
var _feedback_intro_tween: Tween
var _is_feedback_mode := false

@onready var streak_view: Control = $StreakView
@onready var map_hud: CanvasLayer = $StreakView/MapHud
@onready var streak_count_label: Label = $StreakView/nroRacha
@onready var streak_title_label: Label = $StreakView/RachaDiaria
@onready var streak_bar: Sprite2D = $StreakView/contenedorRacha
@onready var back_button: Button = $StreakView/MapHud/HudRoot/BackAnchor/BackButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	streak_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	streak_view.offset_left = 0.0
	streak_view.offset_top = 0.0
	streak_view.offset_right = 0.0
	streak_view.offset_bottom = 0.0
	_cache_progress_nodes()
	_ensure_detail_label()
	_ensure_progress_overlay()
	_ensure_continue_button()
	_connect_map_hud()
	_load_entry_state()


func render(streak_view_model: Dictionary = {}) -> void:
	_feedback_continue_target = {}
	_configure_feedback_controls(false)
	_apply_view_model(_resolve_view_model(streak_view_model))


func _load_entry_state() -> void:
	var feedback: Dictionary = _consume_root_meta_dictionary(STREAK_FEEDBACK_META)
	_feedback_continue_target = _consume_root_meta_dictionary(
		STREAK_CONTINUE_TARGET_META
	)
	if feedback.is_empty():
		_render_current_state()
		return
	_show_feedback(feedback)


func _render_current_state() -> void:
	render()


func _show_feedback(feedback: Dictionary) -> void:
	var base_view_model: Dictionary = _resolve_view_model({})
	_apply_view_model(base_view_model)
	_current_count = max(1, int(feedback.get("current_count", _current_count)))
	_best_count = max(_current_count, int(feedback.get("best_count", _best_count)))
	if _status_key == "inactive":
		_status_key = "active_today"
	_status_detail = _build_feedback_message(feedback)
	_configure_feedback_controls(true)
	_refresh_ui()
	_play_feedback_intro()


func _resolve_view_model(streak_view_model: Dictionary) -> Dictionary:
	if not streak_view_model.is_empty():
		return streak_view_model
	var global_node: Node = get_node_or_null("/root/Global")
	if global_node != null and global_node.has_method("get_streak_view_model"):
		var resolved_view_model: Variant = global_node.call("get_streak_view_model")
		if resolved_view_model is Dictionary:
			return resolved_view_model
	return {}


func _apply_view_model(streak_view_model: Dictionary) -> void:
	_current_count = max(0, int(streak_view_model.get("current_count", 0)))
	_best_count = max(_current_count, int(streak_view_model.get("best_count", 0)))
	_status_key = str(streak_view_model.get("status_key", "inactive")).strip_edges()
	_status_detail = str(streak_view_model.get("status_detail", "")).strip_edges()
	_refresh_ui()


func _refresh_ui() -> void:
	if not is_node_ready():
		return

	streak_count_label.text = str(_current_count)
	streak_title_label.text = DEFAULT_TITLE
	_apply_status_detail_text()
	_apply_status_colors()
	_update_bar_visual()
	_update_connector_visuals()
	_update_day_circles()
	if not _is_feedback_mode:
		_update_pulse_state()


func _cache_progress_nodes() -> void:
	_day_circles = [
		$StreakView/HBoxContainer/DayCircle/TextureRect,
		$StreakView/HBoxContainer/DayCircle2/TextureRect,
		$StreakView/HBoxContainer/DayCircle3/TextureRect,
		$StreakView/HBoxContainer/DayCircle4/TextureRect,
		$StreakView/HBoxContainer/DayCircle5/TextureRect,
		$StreakView/HBoxContainer/DayCircle6/TextureRect,
		$StreakView/HBoxContainer/DayCircle7/TextureRect,
	]
	_connector_sprites = [
		$StreakView/HBoxContainer/lunYMar,
		$StreakView/HBoxContainer/lunAMier,
		$StreakView/HBoxContainer/lunAJue,
		$StreakView/HBoxContainer/lunAVie,
		$StreakView/HBoxContainer/lunASab,
		$StreakView/HBoxContainer/lunADom,
	]


func _ensure_detail_label() -> void:
	_detail_label = streak_view.get_node_or_null("EstadoRacha") as Label
	if _detail_label == null:
		_detail_label = Label.new()
		_detail_label.name = "EstadoRacha"
		_detail_label.offset_left = 330.0
		_detail_label.offset_top = 612.0
		_detail_label.offset_right = 820.0
		_detail_label.offset_bottom = 692.0
		_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_label.add_theme_font_size_override("font_size", 21)
		streak_view.add_child(_detail_label)


func _ensure_progress_overlay() -> void:
	_progress_overlay = streak_view.get_node_or_null("ProgressOverlay") as Control
	if _progress_overlay == null:
		_progress_overlay = Control.new()
		_progress_overlay.name = "ProgressOverlay"
		_progress_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		streak_view.add_child(_progress_overlay)

	_progress_fill = _progress_overlay.get_node_or_null("ProgressFill") as Panel
	if _progress_fill == null:
		_progress_fill = Panel.new()
		_progress_fill.name = "ProgressFill"
		_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_overlay.add_child(_progress_fill)
		_progress_overlay.move_child(_progress_fill, 0)

	_progress_dot_nodes.clear()
	for day_index in range(MAX_VISIBLE_DAYS):
		var dot_name := "ProgressDot%d" % (day_index + 1)
		var dot_panel := _progress_overlay.get_node_or_null(dot_name) as Panel
		if dot_panel == null:
			dot_panel = Panel.new()
			dot_panel.name = dot_name
			dot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_progress_overlay.add_child(dot_panel)
		_progress_dot_nodes.append(dot_panel)
	_progress_overlay.visible = false


func _ensure_continue_button() -> void:
	_continue_button = streak_view.get_node_or_null("ContinueButton") as Button
	if _continue_button == null:
		_continue_button = Button.new()
		_continue_button.name = "ContinueButton"
		streak_view.add_child(_continue_button)
	_continue_button.anchor_left = 1.0
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_right = 1.0
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_left = -220.0
	_continue_button.offset_top = -210.0
	_continue_button.offset_right = -12.0
	_continue_button.offset_bottom = -12.0
	_continue_button.scale = Vector2(0.62, 0.62)
	_continue_button.text = ""
	_continue_button.icon = FORWARD_ARROW_TEXTURE
	_continue_button.expand_icon = true
	_continue_button.focus_mode = Control.FOCUS_NONE
	_continue_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_continue_button.flat = false
	var empty_style := StyleBoxEmpty.new()
	_continue_button.add_theme_stylebox_override("normal", empty_style)
	_continue_button.add_theme_stylebox_override("hover", empty_style)
	_continue_button.add_theme_stylebox_override("pressed", empty_style)
	_continue_button.add_theme_stylebox_override("focus", empty_style)
	_continue_button.add_theme_stylebox_override("disabled", empty_style)
	_continue_button.visible = false
	_continue_button.disabled = true
	if not _continue_button.pressed.is_connected(_on_continue_button_pressed):
		_continue_button.pressed.connect(_on_continue_button_pressed)


func _build_progress_fill_style(track_height: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var radius := int(track_height * 0.5)
	style.bg_color = TRACK_FILL_COLOR
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.71, 0.56, 0.24, 0.18)
	style.shadow_size = 8
	return style


func _build_progress_dot_style(dot_color: Color, dot_size: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var radius := int(dot_size * 0.5)
	style.bg_color = dot_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0, 0, 0, 0.04)
	style.shadow_size = 2
	return style


func _layout_progress_overlay() -> void:
	if _progress_overlay == null or streak_bar == null or streak_bar.texture == null:
		return

	var bar_texture_size: Vector2 = streak_bar.texture.get_size()
	var bar_scale := Vector2(absf(streak_bar.scale.x), absf(streak_bar.scale.y))
	var bar_display_size := Vector2(
		bar_texture_size.x * bar_scale.x,
		bar_texture_size.y * bar_scale.y
	)
	_progress_overlay.position = streak_bar.position - bar_display_size * 0.5
	_progress_overlay.size = bar_display_size

	var overlay_global_rect: Rect2 = _progress_overlay.get_global_rect()
	_progress_dot_centers.clear()
	for day_circle in _day_circles:
		var day_circle_control := day_circle as Control
		if day_circle_control == null:
			continue
		day_circle_control.visible = true
		var day_circle_center_global: Vector2 = day_circle_control.get_global_rect().get_center()
		_progress_dot_centers.append(day_circle_center_global - overlay_global_rect.position)

	var dot_size := clampf(bar_display_size.y * 0.28, 22.0, 34.0)
	if _progress_dot_centers.size() >= 2:
		dot_size = minf(
			dot_size,
			(_progress_dot_centers[1].x - _progress_dot_centers[0].x) * 0.34
		)

	for dot_index in range(_progress_dot_nodes.size()):
		var dot_panel: Panel = _progress_dot_nodes[dot_index]
		if dot_panel == null:
			continue
		if dot_index >= _progress_dot_centers.size():
			dot_panel.visible = false
			continue
		dot_panel.visible = true
		dot_panel.size = Vector2(dot_size, dot_size)
		dot_panel.position = _progress_dot_centers[dot_index] - Vector2.ONE * dot_size * 0.5

	_progress_fill.position = Vector2.ZERO
	_progress_fill.size = Vector2(0.0, bar_display_size.y)
	_progress_fill.add_theme_stylebox_override(
		"panel",
		_build_progress_fill_style(bar_display_size.y)
	)


func _update_progress_overlay() -> void:
	if _progress_overlay == null or _progress_fill == null:
		return

	var visible_day_count: int = _get_visible_day_count()
	if visible_day_count <= 0 or _progress_dot_centers.is_empty():
		_progress_fill.visible = false
	else:
		_progress_fill.visible = true
		var last_active_center: Vector2 = _progress_dot_centers[visible_day_count - 1]
		var dot_width: float = _progress_dot_nodes[0].size.x if not _progress_dot_nodes.is_empty() else 24.0
		var fill_width := clampf(
			last_active_center.x + dot_width * 0.66,
			dot_width,
			_progress_overlay.size.x
		)
		_progress_fill.size = Vector2(fill_width, _progress_overlay.size.y)
		_progress_fill.add_theme_stylebox_override(
			"panel",
			_build_progress_fill_style(_progress_overlay.size.y)
		)

	for dot_index in range(_progress_dot_nodes.size()):
		var dot_panel: Panel = _progress_dot_nodes[dot_index]
		if dot_panel == null or not dot_panel.visible:
			continue
		var dot_color := TRACK_DOT_FUTURE_COLOR
		if dot_index < visible_day_count:
			dot_color = TRACK_DOT_ACTIVE_COLOR
		if _status_key == "active_today" and dot_index == visible_day_count - 1:
			dot_color = TRACK_DOT_CURRENT_COLOR
		dot_panel.add_theme_stylebox_override(
			"panel",
			_build_progress_dot_style(dot_color, dot_panel.size.x)
		)


func _connect_map_hud() -> void:
	if map_hud == null or not map_hud.has_signal("back_requested"):
		return
	var callback := Callable(self, "_on_back_requested")
	if not map_hud.is_connected("back_requested", callback):
		map_hud.connect("back_requested", callback)


func _configure_feedback_controls(enabled: bool) -> void:
	_is_feedback_mode = enabled
	if _continue_button != null:
		_continue_button.visible = enabled
		_continue_button.disabled = not enabled
	if back_button != null:
		back_button.visible = not enabled


func _apply_status_detail_text() -> void:
	if _detail_label == null:
		return
	if _status_detail.is_empty() and _best_count > 0:
		_detail_label.text = "Mejor racha: %d dias" % _best_count
	elif _status_detail.is_empty():
		_detail_label.text = "Completa una actividad para iniciar la racha."
	else:
		_detail_label.text = _status_detail


func _apply_status_colors() -> void:
	if _detail_label == null:
		return
	match _status_key:
		"active_today":
			_detail_label.add_theme_color_override(
				"font_color",
				Color(0.35, 0.25, 0.08, 0.94)
			)
			streak_count_label.modulate = Color(0, 0, 0, 1)
		"pending_today":
			_detail_label.add_theme_color_override(
				"font_color",
				Color(0.34, 0.28, 0.18, 0.9)
			)
			streak_count_label.modulate = Color(0.08, 0.08, 0.08, 0.98)
		_:
			_detail_label.add_theme_color_override(
				"font_color",
				Color(0.38, 0.38, 0.38, 0.82)
			)
			streak_count_label.modulate = Color(0.12, 0.12, 0.12, 0.88)


func _update_bar_visual() -> void:
	if streak_bar == null:
		return
	streak_bar.texture = EMPTY_STREAK_BAR_TEXTURE
	streak_bar.modulate = Color(1, 1, 1, 1)


func _update_connector_visuals() -> void:
	var visible_day_count: int = _get_visible_day_count()
	for connector_index in range(_connector_sprites.size()):
		var connector_sprite: Sprite2D = _connector_sprites[connector_index]
		if connector_sprite == null:
			continue
		connector_sprite.visible = false
		connector_sprite.modulate = Color.WHITE

	if visible_day_count < 2:
		return

	var segment_index := clampi(visible_day_count - 2, 0, _connector_sprites.size() - 1)
	var active_segment: Sprite2D = _connector_sprites[segment_index]
	if active_segment != null:
		active_segment.visible = true


func _update_day_circles() -> void:
	var visible_day_count: int = _get_visible_day_count()
	for circle_node in _day_circles:
		var circle_control := circle_node as Control
		if circle_control == null:
			continue
		var slot := circle_control.get_parent() as Control
		if slot != null:
			slot.visible = true
		circle_control.visible = false
		circle_control.scale = Vector2.ONE
		circle_control.modulate = Color.WHITE

	if visible_day_count <= 0:
		return

	var active_day_index := clampi(visible_day_count - 1, 0, _day_circles.size() - 1)
	var active_circle := _day_circles[active_day_index] as Control
	if active_circle == null or not active_circle.has_method("set_estado"):
		return
	active_circle.visible = true
	active_circle.call(
		"set_estado",
		DayCircleScript.Estado.HOY if _status_key == "active_today" else DayCircleScript.Estado.COMPLETO
	)


func _play_feedback_intro() -> void:
	_stop_feedback_tweens()

	var count_alpha: float = streak_count_label.modulate.a
	var title_alpha: float = streak_title_label.modulate.a
	var detail_alpha: float = _detail_label.modulate.a if _detail_label != null else 1.0
	streak_count_label.pivot_offset = streak_count_label.size * 0.5
	streak_count_label.scale = Vector2(0.60, 0.60)
	streak_count_label.modulate.a = 0.0
	streak_title_label.modulate.a = 0.0
	if _detail_label != null:
		_detail_label.modulate.a = 0.0
	if _continue_button != null:
		_continue_button.modulate.a = 0.0

	for connector_sprite in _connector_sprites:
		if connector_sprite == null or not connector_sprite.visible:
			continue
		connector_sprite.modulate.a = 0.0

	for circle_node in _day_circles:
		var circle_control := circle_node as Control
		if circle_control == null or not circle_control.visible:
			continue
		circle_control.pivot_offset = circle_control.size * 0.5
		circle_control.scale = Vector2(0.70, 0.70)
		circle_control.modulate.a = 0.0

	_feedback_intro_tween = create_tween().set_parallel(false)
	_feedback_intro_tween.tween_property(streak_title_label, "modulate:a", title_alpha, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_intro_tween.parallel().tween_property(
		streak_count_label,
		"modulate:a",
		count_alpha,
		0.18
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_intro_tween.parallel().tween_property(
		streak_count_label,
		"scale",
		Vector2(1.12, 1.12),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_intro_tween.tween_property(streak_count_label, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _detail_label != null:
		_feedback_intro_tween.tween_property(
			_detail_label,
			"modulate:a",
			detail_alpha,
			0.20
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for connector_sprite in _connector_sprites:
		if connector_sprite == null or not connector_sprite.visible:
			continue
		_feedback_intro_tween.tween_property(
			connector_sprite,
			"modulate:a",
			1.0,
			0.16
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for circle_node in _day_circles:
		var circle_control := circle_node as Control
		if circle_control == null or not circle_control.visible:
			continue
		_feedback_intro_tween.tween_property(
			circle_control,
			"scale",
			Vector2(1.12, 1.12),
			0.12
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_feedback_intro_tween.parallel().tween_property(
			circle_control,
			"modulate:a",
			1.0,
			0.10
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_feedback_intro_tween.tween_property(circle_control, "scale", Vector2.ONE, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _continue_button != null:
		_feedback_intro_tween.tween_property(_continue_button, "modulate:a", 1.0, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_feedback_intro_tween.tween_callback(_update_pulse_state)


func _update_pulse_state() -> void:
	_stop_pulse_animation()
	if _status_key != "active_today":
		return
	var visible_day_count: int = _get_visible_day_count()
	if visible_day_count <= 0 or visible_day_count > _day_circles.size():
		return
	var current_circle := _day_circles[visible_day_count - 1] as Control
	if current_circle == null or not current_circle.visible:
		return
	current_circle.pivot_offset = current_circle.size * 0.5
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(current_circle, "scale", Vector2(1.08, 1.08), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(current_circle, "scale", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_feedback_tweens() -> void:
	if _feedback_intro_tween != null and is_instance_valid(_feedback_intro_tween):
		_feedback_intro_tween.kill()
	_feedback_intro_tween = null
	_stop_pulse_animation()


func _stop_pulse_animation() -> void:
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_pulse_tween = null
	for circle_node in _day_circles:
		var circle_control := circle_node as Control
		if circle_control != null:
			circle_control.scale = Vector2.ONE


func _get_visible_day_count() -> int:
	return clampi(_current_count, 0, MAX_VISIBLE_DAYS)


func _build_feedback_message(feedback: Dictionary) -> String:
	match str(feedback.get("feedback_key", "")).strip_edges():
		"activated":
			return STATUS_MESSAGE_ACTIVATED
		"sustained":
			return STATUS_MESSAGE_SUSTAINED
	var fallback_message: String = str(feedback.get("message", "")).strip_edges()
	if not fallback_message.is_empty():
		return fallback_message
	return STATUS_MESSAGE_SUSTAINED


func _consume_root_meta_dictionary(meta_key: String) -> Dictionary:
	if get_tree() == null or get_tree().root == null:
		return {}
	var tree_root: Window = get_tree().root
	if not tree_root.has_meta(meta_key):
		return {}
	var raw_meta: Variant = tree_root.get_meta(meta_key, {})
	tree_root.remove_meta(meta_key)
	if raw_meta is Dictionary:
		return (raw_meta as Dictionary).duplicate(true)
	return {}


func _on_continue_button_pressed() -> void:
	_stop_feedback_tweens()
	if _feedback_continue_target.is_empty():
		_on_back_requested()
		return
	_go_to_continue_target(_feedback_continue_target)


func _go_to_continue_target(continue_target: Dictionary) -> void:
	match str(continue_target.get("type", "")).strip_edges():
		"map":
			GameSceneRouter.go_to_map(get_tree())
		"track_level":
			GameSceneRouter.go_to_track_level(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges(),
				int(continue_target.get("level_number", -1))
			)
		"track_book":
			GameSceneRouter.go_to_track_book(
				get_tree(),
				str(continue_target.get("track_key", "")).strip_edges()
			)
		_:
			_on_back_requested()


func _on_back_requested() -> void:
	_stop_feedback_tweens()
	if get_tree() == null:
		return
	get_tree().change_scene_to_file(_resolve_return_scene_path())


func _resolve_return_scene_path() -> String:
	if get_tree() == null or get_tree().root == null:
		return DEFAULT_RETURN_SCENE
	var tree_root: Window = get_tree().root
	if not tree_root.has_meta(STREAK_RETURN_SCENE_META):
		return DEFAULT_RETURN_SCENE
	var return_scene_path: String = str(
		tree_root.get_meta(STREAK_RETURN_SCENE_META, "")
	).strip_edges()
	tree_root.remove_meta(STREAK_RETURN_SCENE_META)
	return return_scene_path if not return_scene_path.is_empty() else DEFAULT_RETURN_SCENE
