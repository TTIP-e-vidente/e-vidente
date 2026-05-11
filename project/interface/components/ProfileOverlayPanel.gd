extends Control
class_name ProfileOverlayPanel

const RUBIK_FONT := preload("res://fonts/Rubik-VariableFont_wght.ttf")
const RUBIK_MAPS_FONT := preload("res://fonts/RubikMaps-Regular.ttf")

signal resume_pressed
signal save_pressed
signal edit_profile_pressed
signal reset_progress_pressed
signal close_requested

@onready var _overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var _session_panel: PanelContainer = $SessionPanel
@onready var _avatar_preview: TextureRect = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/AvatarContainer/AvatarBg/CenterContainer/AvatarPreview
@onready var _avatar_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/AvatarContainer/AvatarBg/CenterContainer/AvatarLabel
@onready var _username_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/UsernameLabel
@onready var _email_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/MetaRow/EmailLabel
@onready var _age_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/MetaRow/AgeLabel
@onready var _progress_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/ProgressLabel
@onready var _save_status_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/SaveCard/VBox/SaveStatusLabel
@onready var _resume_hint_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/ResumeCard/VBox/ResumeHintLabel
@onready var _resume_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/ResumeCard/VBox/ResumeButton
@onready var _close_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var _guardar_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/GuardarButton
@onready var _edit_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/EditProfileButton
@onready var _reset_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow/ResetButton


func _ready() -> void:
	_overlay_backdrop.gui_input.connect(_on_entrada_fondo)
	_close_btn.pressed.connect(func(): close_requested.emit())
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_guardar_btn.pressed.connect(func(): save_pressed.emit())
	_edit_btn.pressed.connect(func(): edit_profile_pressed.emit())
	_reset_btn.pressed.connect(func(): reset_progress_pressed.emit())
	_aplicar_fuentes()


func _aplicar_fuentes() -> void:
	for lbl: Label in [
		_username_label, _email_label, _age_label, _progress_label,
		_save_status_label, _resume_hint_label, _avatar_label,
	]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", RUBIK_FONT)


func mostrar_superposicion() -> void:
	refrescar()
	visible = true
	_animar_entrada_deslizada()


func ocultar_superposicion() -> void:
	_animar_salida_deslizada()


func refrescar() -> void:
	var username: String = SaveManager.obtener_nombre_usuario_actual()
	_username_label.text = username
	_avatar_label.text = _iniciales_desde(username)
	var avatar_texture: Texture2D = SaveManager.obtener_textura_avatar_usuario_actual()
	_avatar_preview.texture = avatar_texture
	_avatar_preview.visible = avatar_texture != null
	_avatar_label.visible = avatar_texture == null

	var email: String = SaveManager.obtener_email_usuario_actual()
	_email_label.text = email if not email.is_empty() else "Sin correo"

	var age: int = SaveManager.obtener_edad_usuario_actual()
	_age_label.text = "Edad: %d" % age if age > 0 else ""

	var summary_text := Global.formatear_progreso_resumen_texto(
		Global.obtener_progreso_resumen()
	).strip_edges()
	var exp_text := "EXP total: %d" % SaveManager.get_total_exp()
	_progress_label.text = (
		(summary_text + "\n" + exp_text)
		if not summary_text.is_empty()
		else exp_text
	)

	_save_status_label.text = _formatear_estado(SaveManager.obtener_estado_guardado_actual())

	var can_resume: bool = SaveManager.puede_reanudar_guardado_actual()
	_resume_hint_label.text = (
		"Continuar partida" if can_resume else "Sin partida activa"
	)
	_resume_btn.visible = can_resume
	_resume_btn.disabled = not can_resume


# --- Helpers ---

func _iniciales_desde(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	var initials := ""
	for i in mini(parts.size(), 2):
		if not parts[i].is_empty():
			initials += parts[i][0].to_upper()
	return initials if not initials.is_empty() else "?"


func _formatear_estado(state: String) -> String:
	match state:
		"error": return "Error al guardar"
		"dirty": return "Cambios sin guardar"
		"saved": return "Guardado recientemente"
		_: return "Sin datos"


func _on_entrada_fondo(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()


func _animar_entrada_deslizada() -> void:
	var target_x := _session_panel.offset_left
	_session_panel.offset_left = target_x + 120.0
	_session_panel.offset_right += 120.0
	_session_panel.modulate.a = 0.0
	_overlay_backdrop.color.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay_backdrop, "color:a", 0.38, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "offset_left", target_x, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "offset_right", -16.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_session_panel, "modulate:a", 1.0, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animar_salida_deslizada() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay_backdrop, "color:a", 0.0, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "offset_left", _session_panel.offset_left + 80.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "offset_right", _session_panel.offset_right + 80.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_session_panel, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_on_salida_deslizada_finalizada)


func _on_salida_deslizada_finalizada() -> void:
	visible = false
	_session_panel.offset_left = -490.0
	_session_panel.offset_right = -16.0
	_session_panel.modulate.a = 1.0
