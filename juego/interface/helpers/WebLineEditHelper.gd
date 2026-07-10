class_name WebLineEditHelper
extends RefCounted

# Ajusta LineEdit para touch y teclado virtual en export Web (itch.io / móvil).

const META_TOUCH_READY := "web_line_edit_touch_ready"


static func configurar(
	line_edit: LineEdit,
	keyboard_type: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT
) -> void:
	if not is_instance_valid(line_edit):
		return
	line_edit.virtual_keyboard_enabled = true
	line_edit.virtual_keyboard_type = keyboard_type
	line_edit.focus_mode = Control.FOCUS_ALL
	line_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	if line_edit.has_meta(META_TOUCH_READY):
		return
	line_edit.set_meta(META_TOUCH_READY, true)
	line_edit.gui_input.connect(
		func(event: InputEvent) -> void: _enfocar_si_toque(event, line_edit)
	)


static func configurar_varios(
	line_edits: Array,
	keyboard_type: LineEdit.VirtualKeyboardType = LineEdit.KEYBOARD_TYPE_DEFAULT
) -> void:
	for node in line_edits:
		if node is LineEdit:
			configurar(node as LineEdit, keyboard_type)


static func _enfocar_si_toque(event: InputEvent, line_edit: LineEdit) -> void:
	if not is_instance_valid(line_edit):
		return
	var debe_enfocar := false
	if event is InputEventScreenTouch:
		debe_enfocar = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		debe_enfocar = click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if debe_enfocar:
		line_edit.call_deferred("grab_focus")
		line_edit.accept_event()
