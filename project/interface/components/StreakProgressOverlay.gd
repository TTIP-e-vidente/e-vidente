class_name StreakProgressOverlay
extends CanvasLayer

const WEEK_TARGET_DAYS := 7

const DAY_CIRCLE_SIZE    := 40.0
const DAY_BG_INACTIVE    := Color(0.922, 0.894, 0.843, 1.0)
const DAY_BG_ACTIVE      := Color(0.968627, 0.788235, 0.341176, 1.0)
const DAY_BG_CURRENT     := Color(0.239216, 0.176471, 0.070588, 1.0)
const DAY_BORDER_INACTIVE := Color(0.72, 0.67, 0.56, 0.45)
const DAY_BORDER_ACTIVE   := Color(0.82, 0.62, 0.15, 0.80)
const DAY_BORDER_CURRENT  := Color(0.16, 0.12, 0.05, 0.90)
const DAY_NUM_INACTIVE := Color(0.568627, 0.533333, 0.45098, 0.60)
const DAY_NUM_ACTIVE   := Color(0.15, 0.10, 0.03, 0.90)
const DAY_NUM_CURRENT  := Color(0.97, 0.93, 0.80, 1.0)
const STATUS_MESSAGE_ACTIVATED := "Hoy activaste la racha, segui asi."
const STATUS_MESSAGE_SUSTAINED := "Hoy sostuviste la racha."

signal closed

var _day_labels: Array[Label] = []
var _day_styles: Array[StyleBoxFlat] = []
var _tween: Tween

@onready var overlay: Control    = $Overlay
@onready var backdrop: ColorRect = $Overlay/Backdrop
@onready var _card: Control = $Overlay/MarginContainer/CenterContainer/Card
@onready var _content: Control = (
	$Overlay/MarginContainer/CenterContainer/Card/MarginContainer/Content
)
@onready var _count_label: Label = _content.get_node("CurrentCountLabel") as Label
@onready var _status_label: Label = _content.get_node("StatusLabel") as Label
@onready var _progress_row: HBoxContainer = _content.get_node("ProgressRow") as HBoxContainer
@onready var _continue_btn: Button = _content.get_node("ContinueButton") as Button


func _ready() -> void:
	_init_progress_row()
	_continue_btn.pressed.connect(hide_overlay)
	backdrop.gui_input.connect(_on_backdrop_input)
	hide_overlay()


func show_feedback(data: Dictionary) -> void:
	var current_count: int = max(1, int(data.get("current_count", 1)))
	var feedback_key: String = str(data.get("feedback_key", "activated")).strip_edges()

	_count_label.text = "%d %s" % [
		current_count,
		"DIA" if current_count == 1 else "DIAS"
	]
	_status_label.text = _build_status_message(feedback_key, data)
	_update_progress_row(current_count)
	_play_intro(current_count)


func hide_overlay() -> void:
	if not overlay.visible:
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	overlay.visible = false
	overlay.modulate = Color.WHITE
	_card.scale = Vector2.ONE
	_card.modulate = Color.WHITE
	_count_label.scale = Vector2.ONE
	_count_label.modulate = Color.WHITE
	_status_label.modulate = Color.WHITE
	_continue_btn.modulate = Color.WHITE
	for day_label in _day_labels:
		var circle := day_label.get_parent() as Control
		if circle:
			circle.scale = Vector2.ONE
			circle.modulate = Color.WHITE
	closed.emit()


func _init_progress_row() -> void:
	for child in _progress_row.get_children():
		child.queue_free()
	_day_labels.clear()
	_day_styles.clear()

	var radius := int(DAY_CIRCLE_SIZE / 2.0)
	for day_number in range(1, WEEK_TARGET_DAYS + 1):
		var circle := PanelContainer.new()
		circle.name = "Day%dCircle" % day_number
		circle.custom_minimum_size = Vector2(DAY_CIRCLE_SIZE, DAY_CIRCLE_SIZE)

		var style := StyleBoxFlat.new()
		style.corner_radius_top_left    = radius
		style.corner_radius_top_right   = radius
		style.corner_radius_bottom_left  = radius
		style.corner_radius_bottom_right = radius
		style.bg_color = DAY_BG_INACTIVE
		style.border_width_left   = 1
		style.border_width_top    = 1
		style.border_width_right  = 1
		style.border_width_bottom = 1
		style.border_color = DAY_BORDER_INACTIVE
		circle.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.name = "Day%dLabel" % day_number
		label.text = str(day_number)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_FILL
		label.size_flags_vertical   = Control.SIZE_FILL
		label.add_theme_font_size_override("font_size", 15)
		label.modulate = DAY_NUM_INACTIVE
		circle.add_child(label)

		_progress_row.add_child(circle)
		_day_labels.append(label)
		_day_styles.append(style)


func _update_progress_row(current_count: int) -> void:
	var highlighted_days := mini(current_count, WEEK_TARGET_DAYS)
	for day_index in range(_day_labels.size()):
		var day_number := day_index + 1
		var is_active := day_number <= highlighted_days
		var is_current_visible_day := day_number == highlighted_days
		_apply_day_visual_state(
			_day_labels[day_index],
			is_active,
			is_current_visible_day
		)


func _apply_day_visual_state(
	day_label: Label,
	is_active: bool,
	is_current_visible_day: bool
) -> void:
	var day_index := _day_labels.find(day_label)
	if day_index < 0:
		return
	var style := _day_styles[day_index]
	if is_current_visible_day:
		style.bg_color    = DAY_BG_CURRENT
		style.border_color = DAY_BORDER_CURRENT
		day_label.modulate = DAY_NUM_CURRENT
		day_label.add_theme_font_size_override("font_size", 16)
	elif is_active:
		style.bg_color    = DAY_BG_ACTIVE
		style.border_color = DAY_BORDER_ACTIVE
		day_label.modulate = DAY_NUM_ACTIVE
		day_label.add_theme_font_size_override("font_size", 15)
	else:
		style.bg_color    = DAY_BG_INACTIVE
		style.border_color = DAY_BORDER_INACTIVE
		day_label.modulate = DAY_NUM_INACTIVE
		day_label.add_theme_font_size_override("font_size", 15)


func _play_intro(current_count: int) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()

	# Initial state — everything hidden/scaled down
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.88, 0.88)
	_card.modulate = Color(1, 1, 1, 0)
	_count_label.scale = Vector2(0.80, 0.80)
	_count_label.pivot_offset = _count_label.size / 2.0
	_count_label.modulate = Color(1, 1, 1, 0)
	_status_label.modulate = Color(1, 1, 1, 0)
	_continue_btn.modulate = Color(1, 1, 1, 0)
	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)

	var active_count := mini(current_count, _day_labels.size())
	for day_index in range(active_count):
		var circle := _day_labels[day_index].get_parent() as Control
		if circle:
			circle.pivot_offset = circle.size / 2.0
			circle.scale = Vector2(0.70, 0.70)
			circle.modulate = Color(1, 1, 1, 0)

	_tween = create_tween().set_parallel(false)

	# 1. Backdrop fade in
	_tween.tween_property(overlay, "modulate:a", 1.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 2. Card spring in (parallel with backdrop)
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 3. Count label bounce in
	_tween.tween_property(_count_label, "modulate:a", 1.0, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_count_label, "scale", Vector2(1.08, 1.08), 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_count_label, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Status label fade in
	_tween.tween_property(_status_label, "modulate:a", 1.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 5. Day circles staggered pop-in
	for day_index in range(active_count):
		var circle := _day_labels[day_index].get_parent() as Control
		if circle:
			_tween.tween_property(circle, "scale", Vector2.ONE, 0.10) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(circle, "modulate:a", 1.0, 0.10) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_interval(0.06)

	# 6. Button fade in
	_tween.tween_property(_continue_btn, "modulate:a", 1.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_status_message(feedback_key: String, data: Dictionary) -> String:
	match feedback_key:
		"activated":
			return STATUS_MESSAGE_ACTIVATED
		"sustained":
			return STATUS_MESSAGE_SUSTAINED

	var fallback_message := str(data.get("message", "")).strip_edges()
	if not fallback_message.is_empty():
		return fallback_message
	return STATUS_MESSAGE_SUSTAINED


func _on_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		hide_overlay()
