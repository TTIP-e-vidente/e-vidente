class_name StreakProgressOverlay
extends CanvasLayer

const WEEK_TARGET_DAYS := 7

const DAY_CIRCLE_SIZE    := 46.0
const DAY_BG_INACTIVE    := Color(0.93, 0.91, 0.87, 1.0)
const DAY_BG_ACTIVE      := Color(0.96, 0.78, 0.30, 1.0)
const DAY_BG_CURRENT     := Color(0.22, 0.17, 0.07, 1.0)
const DAY_BORDER_INACTIVE := Color(0.80, 0.76, 0.66, 0.35)
const DAY_BORDER_ACTIVE   := Color(0.78, 0.58, 0.12, 0.70)
const DAY_BORDER_CURRENT  := Color(0.96, 0.78, 0.30, 0.90)
const DAY_NUM_INACTIVE := Color(0.55, 0.50, 0.42, 0.50)
const DAY_NUM_ACTIVE   := Color(0.18, 0.13, 0.04, 0.90)
const DAY_NUM_CURRENT  := Color(0.98, 0.94, 0.82, 1.0)
const STATUS_MESSAGE_ACTIVATED := "Hoy activaste la racha, segui asi."
const STATUS_MESSAGE_SUSTAINED := "Hoy sostuviste la racha."
const BEST_STREAK_COLOR := Color(0.50, 0.42, 0.25, 0.60)

signal closed

var _day_labels: Array[Label] = []
var _day_styles: Array[StyleBoxFlat] = []
var _tween: Tween
var _pulse_tween: Tween
var _best_label: Label

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
	_init_best_label()
	_continue_btn.pressed.connect(hide_overlay)
	backdrop.gui_input.connect(_on_backdrop_input)
	hide_overlay()


func show_feedback(data: Dictionary) -> void:
	var current_count: int = max(1, int(data.get("current_count", 1)))
	var best_count: int = int(data.get("best_count", 0))
	var feedback_key: String = str(data.get("feedback_key", "activated")).strip_edges()

	var prefix := "🔥 " if current_count > 1 else ""
	_count_label.text = "%s%d %s" % [
		prefix,
		current_count,
		"DIA" if current_count == 1 else "DIAS"
	]
	_status_label.text = _build_status_message(feedback_key, data)
	_update_best_label(best_count, current_count)
	_update_progress_row(current_count)
	_play_intro(current_count)


func hide_overlay() -> void:
	if not overlay.visible:
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	_tween = null
	_pulse_tween = null
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


func _init_best_label() -> void:
	_best_label = Label.new()
	_best_label.name = "BestStreakLabel"
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.size_flags_horizontal = Control.SIZE_FILL
	_best_label.add_theme_font_size_override("font_size", 14)
	_best_label.modulate = BEST_STREAK_COLOR
	_best_label.visible = false
	var progress_row_index := _progress_row.get_index()
	_content.add_child(_best_label)
	_content.move_child(_best_label, progress_row_index + 1)


func _update_best_label(best_count: int, current_count: int) -> void:
	if best_count > current_count and best_count > 1:
		_best_label.text = "Tu mejor racha: %d dias" % best_count
		_best_label.visible = true
	elif best_count > 0 and current_count >= best_count and current_count > 1:
		_best_label.text = "Nueva mejor racha!"
		_best_label.visible = true
	else:
		_best_label.visible = false


func _apply_day_visual_state(
	day_label: Label,
	is_active: bool,
	is_current_visible_day: bool
) -> void:
	var day_index := _day_labels.find(day_label)
	if day_index < 0:
		return
	var style := _day_styles[day_index]
	var circle := day_label.get_parent() as Control
	if is_current_visible_day:
		style.bg_color    = DAY_BG_CURRENT
		style.border_color = DAY_BORDER_CURRENT
		style.border_width_left   = 3
		style.border_width_top    = 3
		style.border_width_right  = 3
		style.border_width_bottom = 3
		day_label.modulate = DAY_NUM_CURRENT
		day_label.add_theme_font_size_override("font_size", 18)
		if circle:
			circle.custom_minimum_size = Vector2(DAY_CIRCLE_SIZE + 6, DAY_CIRCLE_SIZE + 6)
	elif is_active:
		style.bg_color    = DAY_BG_ACTIVE
		style.border_color = DAY_BORDER_ACTIVE
		style.border_width_left   = 1
		style.border_width_top    = 1
		style.border_width_right  = 1
		style.border_width_bottom = 1
		day_label.modulate = DAY_NUM_ACTIVE
		day_label.add_theme_font_size_override("font_size", 15)
		if circle:
			circle.custom_minimum_size = Vector2(DAY_CIRCLE_SIZE, DAY_CIRCLE_SIZE)
	else:
		style.bg_color    = DAY_BG_INACTIVE
		style.border_color = DAY_BORDER_INACTIVE
		style.border_width_left   = 1
		style.border_width_top    = 1
		style.border_width_right  = 1
		style.border_width_bottom = 1
		day_label.modulate = DAY_NUM_INACTIVE
		day_label.add_theme_font_size_override("font_size", 15)
		if circle:
			circle.custom_minimum_size = Vector2(DAY_CIRCLE_SIZE, DAY_CIRCLE_SIZE)


func _play_intro(current_count: int) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()

	# Initial state — everything hidden/scaled down
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.92, 0.92)
	_card.modulate = Color(1, 1, 1, 0)
	_count_label.scale = Vector2(0.60, 0.60)
	_count_label.pivot_offset = _count_label.size / 2.0
	_count_label.modulate = Color(1, 1, 1, 0)
	_status_label.modulate = Color(1, 1, 1, 0)
	_continue_btn.modulate = Color(1, 1, 1, 0)
	overlay.visible = true
	overlay.modulate = Color(1, 1, 1, 0)

	var active_count := mini(current_count, _day_labels.size())
	for day_index in range(_day_labels.size()):
		var circle := _day_labels[day_index].get_parent() as Control
		if circle:
			circle.pivot_offset = circle.size / 2.0
			if day_index < active_count:
				circle.scale = Vector2(0.50, 0.50)
				circle.modulate = Color(1, 1, 1, 0)
			else:
				circle.scale = Vector2.ONE
				circle.modulate = Color(1, 1, 1, 0)

	_tween = create_tween().set_parallel(false)

	# 1. Backdrop fade in
	_tween.tween_property(overlay, "modulate:a", 1.0, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 2. Card spring in
	_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_card, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 3. Count label bounce in
	_tween.tween_property(_count_label, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_count_label, "scale", Vector2(1.12, 1.12), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_count_label, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Status label fade in
	_tween.tween_property(_status_label, "modulate:a", 1.0, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 5. Inactive day circles fade in together
	for day_index in range(active_count, _day_labels.size()):
		var circle := _day_labels[day_index].get_parent() as Control
		if circle:
			_tween.parallel().tween_property(circle, "modulate:a", 1.0, 0.15) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 6. Active day circles staggered pop-in
	for day_index in range(active_count):
		var circle := _day_labels[day_index].get_parent() as Control
		if circle:
			_tween.tween_property(circle, "scale", Vector2(1.15, 1.15), 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(circle, "modulate:a", 1.0, 0.10) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(circle, "scale", Vector2.ONE, 0.08) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_interval(0.08)

	# 6. Best label fade in (if visible)
	if _best_label.visible:
		_best_label.modulate = Color(BEST_STREAK_COLOR.r, BEST_STREAK_COLOR.g, BEST_STREAK_COLOR.b, 0)
		_tween.tween_property(_best_label, "modulate:a", BEST_STREAK_COLOR.a, 0.20) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 7. Button fade in
	_tween.tween_property(_continue_btn, "modulate:a", 1.0, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# 8. Pulse the current day circle
	if active_count > 0:
		var current_circle := _day_labels[active_count - 1].get_parent() as Control
		if current_circle:
			_tween.tween_callback(_start_current_day_pulse.bind(current_circle))


func _start_current_day_pulse(circle: Control) -> void:
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
	circle.pivot_offset = circle.size / 2.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(circle, "scale", Vector2(1.10, 1.10), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(circle, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


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
