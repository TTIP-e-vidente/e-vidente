extends Control
class_name ProfileOverlayPanel

const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"
const StreakReminderHelperScript := preload("res://interface/auth/StreakReminderHelper.gd")
const MobileUiLayoutHelperScript := preload("res://interface/helpers/MobileUiLayoutHelper.gd")

signal resume_pressed
signal save_pressed
signal edit_profile_pressed
signal reestablecer_progreso_pressed
signal logout_pressed
signal close_requested
signal ranking_pressed(scope: String)

signal login_pressed

@onready var _overlay_backdrop: ColorRect = $OverlayBackdrop
@onready var _session_panel: PanelContainer = $SessionPanel
@onready var _scroll_root: ScrollContainer = $SessionPanel/ScrollContainer
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
@onready var _ranking_detalle: RankingDetallePerfil = (
	$SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/RankingDetallePerfil
)
@onready var _close_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/CloseButton
@onready var _chip_active: PanelContainer = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/ChipActive
@onready var _chip_local: PanelContainer = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/ChipLocal
@onready var _chip_active_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/HeaderRow/ChipActive/Label
@onready var _title_label: Label = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var _guardar_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/GuardarButton
@onready var _edit_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/EditProfileButton
@onready var _leaderboard_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/ActionsRow/LeaderboardButton
@onready var _logout_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow/LogoutButton
@onready var _reset_btn: Button = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow/ResetButton
@onready var _secondary_row: HBoxContainer = $SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/SecondaryRow
@onready var _guest_preferences_panel: VBoxContainer = (
	$SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/GuestPreferencesPanel
)
@onready var _checkbox_omitir_ranking: CheckBox = (
	$SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/GuestPreferencesPanel/CheckboxOmitirRankingPostPartida
)
@onready var _hint_omitir_ranking: Label = (
	$SessionPanel/ScrollContainer/MarginContainer/VBoxContainer/GuestPreferencesPanel/HintOmitirRanking
)

var _syncing: bool = false
var _sincronizando_preferencia_ranking: bool = false


func _ready() -> void:
	_overlay_backdrop.gui_input.connect(_on_entrada_fondo)
	_close_btn.pressed.connect(func(): close_requested.emit())
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_guardar_btn.pressed.connect(_on_cerrar_o_volver_presionado)
	_edit_btn.pressed.connect(_on_editar_perfil_o_login_presionado)
	if is_instance_valid(_leaderboard_btn):
		_leaderboard_btn.pressed.connect(
			func() -> void: ranking_pressed.emit(LeaderboardOverlayHelper.scope_desde_arbol(get_tree()))
		)
	if is_instance_valid(_ranking_detalle):
		_ranking_detalle.ver_tabla_completa_solicitada.connect(
			func(scope: String) -> void: ranking_pressed.emit(scope)
		)
	if _logout_btn:
		_logout_btn.pressed.connect(func(): logout_pressed.emit())
	_reset_btn.pressed.connect(func(): reestablecer_progreso_pressed.emit())
	if is_instance_valid(_checkbox_omitir_ranking):
		_checkbox_omitir_ranking.toggled.connect(_al_cambiar_preferencia_omitir_ranking)
	resized.connect(_ajustar_layout_movil)
	_aplicar_fuentes()
	_configurar_avatar_display()
	call_deferred("_ajustar_layout_movil")


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
	_ajustar_layout_movil()
	refrescar()
	visible = true
	call_deferred("_procesar_deep_link_leaderboard")


func _procesar_deep_link_leaderboard() -> void:
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)



func ocultar_superposicion() -> void:
	visible = false


func mostrar_feedback_reset(message: String, ok: bool = true) -> void:
	if not is_instance_valid(_save_status_label):
		return
	_save_status_label.text = message
	_save_status_label.modulate = MiPaleta.FEEDBACK_OK if ok else MiPaleta.FEEDBACK_ERROR
	if ok:
		refrescar()


func mostrar_feedback_guardado(message: String = "¡Guardado correctamente!") -> void:
	if not is_instance_valid(_save_status_label) or not is_instance_valid(_guardar_btn):
		_syncing = false
		return
	_syncing = true
	_guardar_btn.disabled = true
	_guardar_btn.text = "✓"
	_save_status_label.text = message
	_save_status_label.modulate = MiPaleta.FEEDBACK_OK
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
	var es_invitado := not AuthApi.esta_logueado()
	var username := _resolver_nombre_usuario_visible()
	if es_invitado:
		username = "Modo invitado"
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
	var email_line := email if not email.is_empty() else "Sin correo"
	if es_invitado:
		email_line = "Progreso local en este dispositivo."
	elif AuthApi.esta_logueado() and not email.is_empty():
		var user_online := AuthApi.obtener_usuario_online()
		# str(null) en GDScript da "<null>" (no vacío) — hay que usar el
		# validador compartido, no reimplementar el chequeo con str().
		var verified := AuthApi.mail_verified_at_valido(user_online.get("mail_verified_at", null))
		email_line += "\nVerificación: %s" % ("verificado" if verified else "pendiente")
		var notifications_on := bool(user_online.get("email_notifications_enabled", false))
		var recordatorios := "Sí" if notifications_on else "No"
		if not notifications_on and StreakReminderHelperScript.racha_en_riesgo():
			recordatorios += " (racha en riesgo — activalos en perfil)"
		email_line += "\nRecordatorios mail: %s" % recordatorios
	_email_label.text = email_line

	var age: int = 0
	if _save_manager_listo():
		age = SaveManager.obtener_edad_usuario_actual()
	_age_label.text = "Edad: %d" % age if age > 0 else ""

	var summary_text := ""
	if _save_manager_listo():
		Global.aplicar_progreso_nodos_plano(SaveManager.obtener_todo_progreso_nodos())
	summary_text = Global.formatear_progreso_resumen_texto(
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

	if is_instance_valid(_ranking_detalle):
		var scope_refresh := LeaderboardService.consumir_refresco_tras_partida()
		if AuthApi.esta_logueado() and scope_refresh.is_empty():
			LeaderboardService.prefetch_datos_perfil()
		if not scope_refresh.is_empty():
			_ranking_detalle.call_deferred("cargar", scope_refresh, true)
		else:
			_ranking_detalle.call_deferred("cargar")
		
	if _logout_btn:
		_logout_btn.visible = not es_invitado
	_aplicar_layout_acciones(es_invitado)


func _aplicar_layout_acciones(es_invitado: bool) -> void:
	if is_instance_valid(_chip_active):
		_chip_active.visible = es_invitado
	if is_instance_valid(_chip_local):
		_chip_local.visible = not es_invitado
	if is_instance_valid(_chip_active_label):
		_chip_active_label.text = "Modo invitado"
	if is_instance_valid(_title_label):
		_title_label.visible = not es_invitado

	if es_invitado:
		if is_instance_valid(_guardar_btn):
			_guardar_btn.visible = false
		if is_instance_valid(_edit_btn):
			_edit_btn.visible = true
			_edit_btn.text = "Iniciar sesión"
			_edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_instance_valid(_secondary_row):
			_secondary_row.visible = false
		_configurar_preferencias_invitado(true)
		return

	_configurar_preferencias_invitado(false)

	if is_instance_valid(_secondary_row):
		_secondary_row.visible = true

	if is_instance_valid(_guardar_btn):
		var pending := 0
		if AuthApi.esta_logueado():
			pending = LocalSyncQueue.contar_pendientes()
		_guardar_btn.visible = pending > 0
		if pending > 0:
			_guardar_btn.text = "Sincronizar (%d)" % pending
			_guardar_btn.disabled = _syncing or SyncApi.esta_sincronizando_pendientes()
	if is_instance_valid(_edit_btn):
		_edit_btn.visible = true
		_edit_btn.text = "Editar perfil"
		_edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_instance_valid(_reset_btn):
		_reset_btn.visible = true


func _on_cerrar_o_volver_presionado() -> void:
	if not AuthApi.esta_logueado():
		close_requested.emit()
		return
	_on_guardar_presionado()


func _on_editar_perfil_o_login_presionado() -> void:
	if not AuthApi.esta_logueado():
		login_pressed.emit()
		return
	edit_profile_pressed.emit()


func _configurar_preferencias_invitado(mostrar_prefs: bool) -> void:
	if is_instance_valid(_guest_preferences_panel):
		_guest_preferences_panel.visible = mostrar_prefs
	if not mostrar_prefs or not is_instance_valid(_checkbox_omitir_ranking):
		return
	if is_instance_valid(_hint_omitir_ranking):
		_hint_omitir_ranking.text = LeaderboardFormat.hint_preferencia_omitir_ranking_perfil()
	_checkbox_omitir_ranking.text = LeaderboardFormat.texto_preferencia_omitir_ranking_perfil()
	_sincronizando_preferencia_ranking = true
	_checkbox_omitir_ranking.button_pressed = SaveManager.omitir_ranking_post_partida_invitado()
	_sincronizando_preferencia_ranking = false


func _al_cambiar_preferencia_omitir_ranking(omitir: bool) -> void:
	if _sincronizando_preferencia_ranking:
		return
	PostPartidaFlow.persistir_preferencia_omitir_ranking(omitir)


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
		if not AuthApi.esta_logueado():
			return SaveManager.DEFAULT_PROFILE_NAME
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
		return "Modo invitado — progreso solo local"
	var pending_count: int = LocalSyncQueue.contar_pendientes()
	if pending_count <= 0:
		return base
	var plural: String = "s" if pending_count != 1 else ""
	return base + "\n%d partida%s sin sincronizar" % [pending_count, plural]


func _ajustar_layout_movil() -> void:
	if not is_instance_valid(_session_panel):
		return
	MobileUiLayoutHelperScript.aplicar_panel_lateral(_session_panel, size.x)
	if is_instance_valid(_scroll_root):
		MobileUiLayoutHelperScript.estilizar_scroll_discreto(_scroll_root)
	var margen := 16 if MobileUiLayoutHelperScript.es_pantalla_estrecha(self) else 26
	var margin_container := _session_panel.get_node_or_null("ScrollContainer/MarginContainer")
	if margin_container is MarginContainer:
		var margins := margin_container as MarginContainer
		margins.add_theme_constant_override("margin_left", margen)
		margins.add_theme_constant_override("margin_right", margen)
		margins.add_theme_constant_override("margin_top", margen)
		margins.add_theme_constant_override("margin_bottom", margen)
	if is_instance_valid(_close_btn):
		MobileUiLayoutHelperScript.asegurar_minimo_tactil(_close_btn)


func _on_entrada_fondo(event: InputEvent) -> void:
	if MobileUiLayoutHelperScript.cerrar_si_toque_fondo(event):
		close_requested.emit()


func _animar_entrada_deslizada() -> void:
	var target_x := _session_panel.offset_left
	_session_panel.modulate.a = 0.0
	_overlay_backdrop.color.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay_backdrop, "color:a", 0.35, 0.25)\
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
	_session_panel.offset_left = MobileUiLayoutHelperScript.offset_cerrado_panel_lateral(size.x)
	_session_panel.offset_right = -16.0
	_session_panel.modulate.a = 1.0
