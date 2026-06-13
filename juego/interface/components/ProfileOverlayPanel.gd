extends Control
class_name ProfileOverlayPanel

const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"

signal resume_pressed
signal save_pressed
signal edit_profile_pressed
signal reestablecer_progreso_pressed
signal logout_pressed
signal close_requested

@onready var _overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var _session_panel: PanelContainer = $SessionPanel
@onready var _avatar_preview: TextureRect = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/AvatarContainer/AvatarBg/CenterContainer/AvatarPreview
@onready var _avatar_bg: Control = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/AvatarContainer/AvatarBg
@onready var _avatar_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/AvatarContainer/AvatarBg/CenterContainer/AvatarLabel
@onready var _username_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/UsernameLabel
@onready var _email_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/MetaRow/EmailLabel
@onready var _age_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/MetaRow/AgeLabel
@onready var _progress_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SummaryPanel/SummaryRow/InfoColumn/ProgressLabel
@onready var _save_status_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/SaveCard/VBox/SaveStatusLabel
@onready var _resume_hint_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/ResumeCard/VBox/ResumeHintLabel
@onready var _resume_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/StatusRow/ResumeCard/VBox/ResumeButton
@onready var _weekly_summary: Node = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/WeeklyLearningSummary
@onready var _close_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var _guardar_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/GuardarButton
@onready var _edit_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/EditProfileButton
@onready var _logout_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow/LogoutButton
@onready var _reset_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow/ResetButton

var _syncing: bool = false


func _ready() -> void:
	_overlay_backdrop.gui_input.connect(_on_entrada_fondo)
	_close_btn.pressed.connect(func(): close_requested.emit())
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_guardar_btn.pressed.connect(_on_guardar_presionado)
	_edit_btn.pressed.connect(func(): edit_profile_pressed.emit())
	if _logout_btn:
		_logout_btn.pressed.connect(func(): logout_pressed.emit())
	_reset_btn.pressed.connect(func(): reestablecer_progreso_pressed.emit())
	_aplicar_fuentes()
	_configurar_avatar_display()


func _configurar_avatar_display() -> void:
	if is_instance_valid(_avatar_preview):
		_avatar_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_avatar_preview.custom_minimum_size = Vector2(56, 56)
	if is_instance_valid(_avatar_bg):
		_avatar_bg.clip_contents = true


func _aplicar_fuentes() -> void:
	var rubik_font: Font = load(RUBIK_FONT_PATH) as Font
	for lbl: Label in [
		_email_label, _age_label, _progress_label,
		_save_status_label, _resume_hint_label, _avatar_label,
	]:
		if is_instance_valid(lbl) and rubik_font != null:
			lbl.add_theme_font_override("font", rubik_font)


func mostrar_superposicion() -> void:
	refrescar()
	visible = true



func ocultar_superposicion() -> void:
	visible = false


func mostrar_feedback_guardado(message: String = "¡Guardado correctamente!") -> void:
	if not is_instance_valid(_save_status_label) or not is_instance_valid(_guardar_btn):
		_syncing = false
		return
	_syncing = true
	_guardar_btn.disabled = true
	_guardar_btn.text = "✓"
	_save_status_label.text = message
	await get_tree().create_timer(2.5).timeout
	_syncing = false
	if is_instance_valid(_guardar_btn):
		_guardar_btn.disabled = false
		_guardar_btn.text = "Guardar ahora"
	if is_instance_valid(self):
		refrescar()


func _on_guardar_presionado() -> void:
	if not is_instance_valid(_guardar_btn) or _guardar_btn.disabled:
		return

	if _save_manager_listo():
		SaveManager.guardar_progreso_en_disco()
	save_pressed.emit()

	if not AuthApi.esta_logueado():
		mostrar_feedback_guardado("Guardado localmente")
		return

	# Sube el avatar al backend si hay uno local (fire-and-forget).
	_subir_avatar_si_tiene()

	var pending := LocalSyncQueue.listar_pendientes()
	if pending.is_empty():
		mostrar_feedback_guardado("Todo al día ✓")
		return

	var n := pending.size()
	var plural := "s" if n != 1 else ""
	_syncing = true
	_guardar_btn.disabled = true
	_guardar_btn.text = "Sincronizando..."
	_save_status_label.text = "Enviando %d partida%s al servidor..." % [n, plural]
	SyncApi.conectar_feedback_sincronizacion_one_shot(_al_sync_pendientes_terminado)
	SyncApi.reintentar_todos_pendientes()


func _subir_avatar_si_tiene() -> void:
	if not _save_manager_listo():
		return
	var path := SaveManager.obtener_ruta_avatar_usuario_actual()
	if path.is_empty():
		return
	if not SaveManager.es_ruta_avatar_vinculada(path):
		print("[ProfileOverlay] Avatar upload skipped: local avatar is not linked to active account.")
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var base64_data := Marshalls.raw_to_base64(bytes)
	var ext := path.get_extension().to_lower()
	var mime_type := "image/png"
	if ext == "jpg" or ext == "jpeg":
		mime_type = "image/jpeg"
	elif ext == "webp":
		mime_type = "image/webp"
	var result := await BackendSession.subir_avatar(base64_data, mime_type)
	if not bool(result.get("ok", false)):
		print("[ProfileOverlay] Avatar upload failed: ", result.get("error", ""))


func _al_sync_pendientes_terminado(synced: int, failed: int) -> void:
	if synced > 0 and AuthApi.esta_logueado():
		await BackendSession.cargar_datos_online()
	mostrar_feedback_guardado(SyncApi.mensaje_resultado_batch_perfil(synced, failed))


func _save_manager_listo() -> bool:
	return SaveManager != null and SaveManager.has_method("cargar_datos")


func refrescar() -> void:
	var username := _resolver_nombre_usuario_visible()
	_username_label.text = username
	_avatar_label.text = _iniciales_desde(username)
	var avatar_texture: Texture2D = null
	if _save_manager_listo():
		avatar_texture = SaveManager.obtener_textura_avatar_usuario_actual()
	_avatar_preview.texture = avatar_texture
	_avatar_preview.visible = avatar_texture != null
	_avatar_label.visible = avatar_texture == null

	var email: String = ""
	if _save_manager_listo():
		email = SaveManager.obtener_email_usuario_actual()
	_email_label.text = email if not email.is_empty() else "Sin correo"

	var age: int = 0
	if _save_manager_listo():
		age = SaveManager.obtener_edad_usuario_actual()
	_age_label.text = "Edad: %d" % age if age > 0 else ""

	var summary_text := Global.formatear_progreso_resumen_texto(
		Global.obtener_progreso_resumen()
	).strip_edges()
	var exp_text := "EXP total: 0"
	if _save_manager_listo():
		exp_text = "EXP total: %d" % SaveManager.obtener_exp_total()
	_progress_label.text = (
		(summary_text + "\n" + exp_text)
		if not summary_text.is_empty()
		else exp_text
	)

	if not _syncing:
		_save_status_label.text = _formatear_estado_con_pendientes()

	var can_resume: bool = _save_manager_listo() and SaveManager.puede_reanudar_guardado_actual()
	_resume_hint_label.text = (
		"Continuar partida" if can_resume else "Sin partida activa"
	)
	_resume_btn.visible = can_resume
	_resume_btn.disabled = not can_resume

	# Refrescar resumen semanal
	if is_instance_valid(_weekly_summary) and _weekly_summary.has_method("refrescar"):
		_weekly_summary.call("refrescar")
		
	if _logout_btn:
		_logout_btn.visible = AuthApi.esta_logueado()


# --- Helpers ---

func _resolver_nombre_usuario_visible() -> String:
	if AuthApi.esta_logueado():
		var online_user := AuthApi.obtener_usuario_online()
		var online_name := str(online_user.get("name", "")).strip_edges()
		if online_name.is_empty():
			online_name = str(online_user.get("username", AuthApi.obtener_usuario())).strip_edges()
		if not online_name.is_empty():
			return online_name
	if _save_manager_listo():
		return SaveManager.obtener_nombre_usuario_actual()
	return ""


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


func _formatear_estado_con_pendientes() -> String:
	var base: String = "Sin datos"
	if _save_manager_listo():
		base = _formatear_estado(SaveManager.obtener_estado_guardado_actual())
	if not AuthApi.esta_logueado():
		return base
	var pending_count: int = LocalSyncQueue.contar_pendientes()
	if pending_count <= 0:
		return base
	var plural: String = "s" if pending_count != 1 else ""
	return base + "\n%d partida%s sin sincronizar" % [pending_count, plural]


func _on_entrada_fondo(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_requested.emit()


func _animar_entrada_deslizada() -> void:
	var target_x := _session_panel.offset_left
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
	tw.tween_property(_session_panel, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_on_salida_deslizada_finalizada)


func _on_salida_deslizada_finalizada() -> void:
	visible = false
	_session_panel.offset_left = -490.0
	_session_panel.offset_right = -16.0
	_session_panel.modulate.a = 1.0


func _on_guardar_button_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
