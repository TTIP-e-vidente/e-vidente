class_name DragObjectiveText
extends Control

@onready var action_label: Label = $ActionLabel
@onready var main_label: Label = $MainLabel
@onready var sub_label: Label = $SubLabel

const _FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"


func _ready() -> void:
	_apply_fonts()
	_apply_style()
	_layout_labels()


func set_objective(data: Dictionary) -> void:
	print_debug("[DragObjectiveText] set_objective data=", data)
	var parsed: Dictionary = _parse_objective(data)
	action_label.text = parsed["label"]
	main_label.text = parsed["main"]
	sub_label.text = parsed["sub"]
	main_label.visible = not main_label.text.strip_edges().is_empty()
	sub_label.visible = not sub_label.text.strip_edges().is_empty()
	_play_intro()


func _apply_fonts() -> void:
	var base_font: FontFile = load(_FONT_PATH) as FontFile
	if base_font == null:
		return
	# ActionLabel — peso medio (500)
	var action_font: FontVariation = FontVariation.new()
	action_font.base_font = base_font
	action_font.variation_opentype = {"wght": 500}
	action_label.add_theme_font_override("font", action_font)
	# MainLabel — negrita / peso alto (700) para mayor jerarquía
	var main_font: FontVariation = FontVariation.new()
	main_font.base_font = base_font
	main_font.variation_opentype = {"wght": 700}
	main_label.add_theme_font_override("font", main_font)
	# SubLabel — peso regular (400)
	var sub_font: FontVariation = FontVariation.new()
	sub_font.base_font = base_font
	sub_font.variation_opentype = {"wght": 400}
	sub_label.add_theme_font_override("font", sub_font)


func _apply_style() -> void:
	action_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 0.92))
	action_label.add_theme_font_size_override("font_size", 18)
	main_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 0.98))
	main_label.add_theme_font_size_override("font_size", 20)
	sub_label.add_theme_color_override("font_color", Color(0.16, 0.16, 0.16, 0.78))
	sub_label.add_theme_font_size_override("font_size", 16)


func _layout_labels() -> void:
	custom_minimum_size = Vector2(330, 120)
	size = Vector2(330, 120)
	_setup_label(action_label, Vector2(0, 0), Vector2(330, 26))
	_setup_label(main_label, Vector2(0, 34), Vector2(330, 30))
	_setup_label(sub_label, Vector2(0, 68), Vector2(330, 24))
	print_debug(
		"[DragObjectiveText] labels layout action=",
		action_label.position,
		" main=",
		main_label.position,
		" sub=",
		sub_label.position
	)


func _setup_label(label: Label, pos: Vector2, label_size: Vector2) -> void:
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _parse_objective(data: Dictionary) -> Dictionary:
	var label_text: String = "Prepará"
	if data.has("objective_label") and str(data.get("objective_label", "")).strip_edges() != "":
		label_text = str(data.get("objective_label", ""))
	elif data.has("label") and str(data.get("label", "")).strip_edges() != "":
		label_text = str(data.get("label", ""))

	if data.has("objective_main"):
		var main_text: String = str(data.get("objective_main", ""))
		var sub_text: String = ""
		if data.has("objective_sub"):
			sub_text = str(data.get("objective_sub", ""))
		return {"label": label_text, "main": main_text, "sub": sub_text}

	if data.has("main"):
		var main_text: String = str(data.get("main", ""))
		var sub_text: String = ""
		if data.has("sub"):
			sub_text = str(data.get("sub", ""))
		return {"label": label_text, "main": main_text, "sub": sub_text}

	var message: String = ""
	if data.has("objective_message"):
		message = str(data.get("objective_message", ""))
	elif data.has("message"):
		message = str(data.get("message", ""))

	if message.strip_edges().is_empty():
		return {"label": label_text, "main": "", "sub": ""}

	var parts: PackedStringArray = message.split("\n", true, 1)
	var main_text: String = parts[0] if parts.size() > 0 else ""
	var sub_text: String = parts[1] if parts.size() > 1 else ""
	return {"label": label_text, "main": main_text, "sub": sub_text}


func _play_intro() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
