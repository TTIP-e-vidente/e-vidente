extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

# Root scene nodes
var reset_progress_dialog: ConfirmationDialog
var mode_selection_streak_badge: Node

# Profile overlay panel and its controls
var profile_overlay: Control
var profile_toggle_button: Button
var close_profile_button: Button
var profile_summary_panel: PanelContainer
var profile_history_panel: PanelContainer
var history_toggle_button: Button
var reset_progress_button: Button

# Profile content labels
var username_label: Label
var email_label: Label
var age_label: Label
var progress_summary_label: Label
var profile_streak_badge: Node
var avatar_preview: TextureRect
var avatar_state_label: Label

# Save and resume section
var save_status_label: Label
var resume_hint_label: Label
var resume_now_button: Button

# History section
var history_log_label: RichTextLabel

# Internal state
var _save_icon_feedback_revision: int = 0


func _ready() -> void:
	_cachear_nodos_raiz()
	_cachear_nodos_overlay()
	_cachear_nodos_contenido_perfil()
	_configurar_ui_estatica()
	_conectar_badge_racha()
	_conectar_senales_save_manager()
	MusicManager.reproducir_musica(MUSICA_FONDO)
	_refrescar_superposicion_perfil()


func _exit_tree() -> void:
	_desconectar_senales_save_manager()


func _cachear_nodos_raiz() -> void:
	reset_progress_dialog = $ResetProgressDialog as ConfirmationDialog
	mode_selection_streak_badge = $CanvasLayer/ModeSelectionStreakBadge


func _cachear_nodos_overlay() -> void:
	var overlay_layer := $ProfileOverlayLayer as CanvasLayer
	profile_toggle_button = overlay_layer.get_node("ProfileToggleButton") as Button
	profile_overlay = overlay_layer.get_node("ProfileOverlay") as Control
	close_profile_button = profile_overlay.get_node("CloseProfileButton") as Button
	profile_summary_panel = profile_overlay.get_node("SessionPanel") as PanelContainer
	profile_history_panel = profile_overlay.get_node("HistoryPanel") as PanelContainer


func _cachear_nodos_contenido_perfil() -> void:
	var profile_content := profile_summary_panel.get_node(
		"MarginContainer/ProfileContent"
	) as Control
	var summary_content := profile_content.get_node(
		"SummaryPanel/MarginContainer/SummaryContent"
	) as Control
	var info_column := summary_content.get_node("InfoColumn") as Control
	var status_row := profile_content.get_node("StatusRow") as Control
	var resume_content := status_row.get_node(
		"ResumeCard/MarginContainer/ResumeContent"
	) as Control
	var secondary_actions_row := profile_content.get_node("SecondaryActionsRow") as Control
	var history_content := profile_history_panel.get_node(
		"MarginContainer/HistoryContent"
	) as Control

	username_label = info_column.get_node("UsernameLabel") as Label
	email_label = info_column.get_node("MetaRow/EmailBadge/MarginContainer/EmailLabel") as Label
	age_label = info_column.get_node("MetaRow/AgeBadge/MarginContainer/AgeLabel") as Label
	progress_summary_label = info_column.get_node("ProgressLabel") as Label
	profile_streak_badge = info_column.get_node("StreakBadge") as Node
	avatar_preview = summary_content.get_node(
		"AvatarColumn/AvatarFrame/MarginContainer/AvatarPreview"
	) as TextureRect
	avatar_state_label = summary_content.get_node("AvatarColumn/AvatarState") as Label
	save_status_label = status_row.get_node("SaveCard/MarginContainer/SaveStatusLabel") as Label
	resume_hint_label = resume_content.get_node("ResumeHintLabel") as Label
	resume_now_button = resume_content.get_node("ResumeNowButton") as Button
	history_toggle_button = secondary_actions_row.get_node("HistoryToggleButton") as Button
	reset_progress_button = secondary_actions_row.get_node("ResetProgressButton") as Button
	history_log_label = history_content.get_node(
		"HistoryBody/MarginContainer/HistoryText"
	) as RichTextLabel


func _configurar_ui_estatica() -> void:
	if profile_toggle_button.has_method("set_label_text"):
		profile_toggle_button.call("set_label_text", "Mi progreso")
	else:
		profile_toggle_button.text = "Mi progreso"
	_establecer_icono_guardado(SAVE_ICON_IDLE)

	reset_progress_button.text = "Reiniciar progreso"
	reset_progress_dialog.title = "Reiniciar progreso"
	reset_progress_dialog.dialog_text = (
		"Esto borrara el avance guardado, el historial y las partidas retomables "
		+ "de este dispositivo. El perfil visible se conserva."
	)
	reset_progress_dialog.get_ok_button().text = "Reiniciar"

	_actualizar_visibilidad_vista_historial(false)
	_sincronizar_visibilidad_botones_superposicion()


func _conectar_badge_racha() -> void:
	if mode_selection_streak_badge == null or not mode_selection_streak_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_badge_racha_selector_modo_presionado")
	if not mode_selection_streak_badge.is_connected("pressed", callback):
		mode_selection_streak_badge.connect("pressed", callback)


func _refrescar_superposicion_perfil() -> void:
	var username: String = SaveManager.obtener_nombre_usuario_actual()
	username_label.text = username
	var email: String = SaveManager.obtener_email_usuario_actual()
	email_label.text = "Mail: %s" % (email if not email.is_empty() else "sin dato")
	var age: int = SaveManager.obtener_edad_usuario_actual()
	age_label.text = "Edad: %s" % (str(age) if age > 0 else "sin dato")

	# Progreso
	var summary_text := Global.formatear_progreso_resumen_texto(
		Global.obtener_progreso_resumen()
	).strip_edges()
	progress_summary_label.text = (
		summary_text
		if not summary_text.is_empty()
		else "Todavia no hay capitulos completos"
	)

	# Racha
	if (
		is_instance_valid(mode_selection_streak_badge)
		and mode_selection_streak_badge.has_method("renderizar")
	):
		mode_selection_streak_badge.call("renderizar")
	if is_instance_valid(profile_streak_badge) and profile_streak_badge.has_method("renderizar"):
		profile_streak_badge.call("renderizar")

	# Estado de guardado
	save_status_label.text = _formatear_estado_guardado()
	var last_saved_at := SaveManager.obtener_ultimo_guardado_en()
	var tooltip := "Abrir guardado local"
	if not last_saved_at.is_empty():
		tooltip += "\nUltimo guardado: %s" % last_saved_at
	profile_toggle_button.tooltip_text = tooltip

	# Reanudar
	var can_resume: bool = SaveManager.puede_reanudar_guardado_actual()
	resume_now_button.visible = can_resume
	resume_now_button.disabled = not can_resume
	resume_hint_label.text = (
		"Retoma en %s" % SaveManager.obtener_pista_reanudacion_actual()
		if can_resume
		else "Todavia no hay un punto guardado"
	)

	# Avatar
	var avatar_texture: Texture2D = SaveManager.obtener_textura_avatar_usuario_actual()
	avatar_preview.texture = avatar_texture
	avatar_state_label.text = "Avatar listo" if avatar_texture != null else "Avatar opcional"

	# Historial
	var history_entries: Array = SaveManager.obtener_historial_guardado_actual()
	history_log_label.text = (
		_construir_texto_log_historial(history_entries)
		if not history_entries.is_empty()
		else "Todavia no hay actividad guardada."
	)

	_sincronizar_visibilidad_botones_superposicion()


func _sincronizar_visibilidad_botones_superposicion() -> void:
	profile_toggle_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible

func _conectar_senales_save_manager() -> void:
	SaveManager.save_status_changed.connect(_on_save_manager_cambiado)
	SaveManager.progress_loaded.connect(_on_save_manager_perfil_cambiado)
	SaveManager.progress_saved.connect(_on_save_manager_perfil_cambiado)
	SaveManager.user_registered.connect(_on_save_manager_perfil_cambiado)


func _desconectar_senales_save_manager() -> void:
	SaveManager.save_status_changed.disconnect(_on_save_manager_cambiado)
	SaveManager.progress_loaded.disconnect(_on_save_manager_perfil_cambiado)
	SaveManager.progress_saved.disconnect(_on_save_manager_perfil_cambiado)
	SaveManager.user_registered.disconnect(_on_save_manager_perfil_cambiado)

func _on_save_manager_cambiado(status: Dictionary) -> void:
	var save_state: String = str(status.get("state", ""))
	if save_state == "saved" or save_state == "recovered":
		_mostrar_icono_guardado_brevemente()
	_refrescar_superposicion_perfil()


func _on_save_manager_perfil_cambiado(_profile: Dictionary) -> void:
	_refrescar_superposicion_perfil()


func _on_boton_toggle_perfil_presionado() -> void:
	_actualizar_visibilidad_superposicion(true)


func _on_boton_cerrar_perfil_presionado() -> void:
	_actualizar_visibilidad_superposicion(false)


func _on_entrada_gui_fondo_perfil(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_actualizar_visibilidad_superposicion(false)


func _on_atras_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	GameSceneRouter.go_to_main_menu(get_tree())


func _on_badge_racha_selector_modo_presionado() -> void:
	_actualizar_visibilidad_superposicion(false)
	GameSceneRouter.go_to_streak(get_tree(), ARCHIVERO_SCENE)


func _on_guardar_presionado() -> void:
	SaveManager.registrar_guardado_manual()


func _on_boton_reanudar_ahora_presionado() -> void:
	if not SaveManager.puede_reanudar_guardado_actual():
		return
	_actualizar_visibilidad_superposicion(false)
	var resume_state: Dictionary = SaveManager.recargar_desde_disco_y_obtener_reanudacion()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_editar_perfil_presionado() -> void:
	SaveManager.guardar_progreso_en_disco()
	get_tree().root.set_meta(
		PROFILE_RETURN_SCENE_META,
		ARCHIVERO_SCENE
	)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_boton_toggle_historial_presionado() -> void:
	_actualizar_visibilidad_vista_historial(not profile_history_panel.visible)


func _on_boton_cerrar_historial_presionado() -> void:
	_actualizar_visibilidad_vista_historial(false)


func _on_boton_reiniciar_progreso_presionado() -> void:
	reset_progress_dialog.popup_centered(Vector2i(440, 220))


func _on_dialogo_reiniciar_progreso_confirmado() -> void:
	_actualizar_visibilidad_vista_historial(false)
	SaveManager.reiniciar_todo_progreso()
	_refrescar_superposicion_perfil()


func _actualizar_visibilidad_superposicion(overlay_visible: bool) -> void:
	profile_overlay.visible = overlay_visible
	_actualizar_visibilidad_vista_historial(false)
	_sincronizar_visibilidad_botones_superposicion()
	if overlay_visible:
		_refrescar_superposicion_perfil()


func _actualizar_visibilidad_vista_historial(history_visible: bool) -> void:
	profile_summary_panel.visible = not history_visible
	profile_history_panel.visible = history_visible
	history_toggle_button.text = (
		"Volver al resumen"
		if history_visible
		else "Ver historial"
	)


func _mostrar_icono_guardado_brevemente() -> void:
	var save_failed := SaveManager.tiene_error_guardado()
	var nothing_was_saved := SaveManager.obtener_motivo_ultimo_guardado().is_empty()
	if save_failed or nothing_was_saved:
		_establecer_icono_guardado(SAVE_ICON_IDLE)
		return

	_save_icon_feedback_revision += 1
	var this_revision := _save_icon_feedback_revision
	_establecer_icono_guardado(SAVE_ICON_OK)
	_revertir_icono_guardado_tras_demora(this_revision)


func _revertir_icono_guardado_tras_demora(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != _save_icon_feedback_revision:
		return
	_establecer_icono_guardado(SAVE_ICON_IDLE)


func _establecer_icono_guardado(icon: Texture2D) -> void:
	if profile_toggle_button == null or not is_instance_valid(profile_toggle_button):
		return
	if profile_toggle_button.has_method("set_status_icon"):
		profile_toggle_button.call("set_status_icon", icon)
		return
	profile_toggle_button.icon = icon


func _construir_texto_log_historial(history: Array) -> String:
	var history_lines: Array[String] = []
	for history_entry in history:
		if not history_entry is Dictionary:
			continue
		history_lines.append(
			"%s\n%s" % [
				history_entry.get("timestamp", ""),
				history_entry.get("message", "")
			]
		)
	return "\n\n".join(history_lines)


func _formatear_estado_guardado() -> String:
	var state := SaveManager.obtener_estado_guardado_actual()
	var last_saved_at := SaveManager.obtener_ultimo_guardado_en()
	if last_saved_at.is_empty():
		last_saved_at = "sin datos"
	var error_message := SaveManager.obtener_error_ultimo_guardado()
	match state:
		"error":
			return "No se pudo guardar.\n%s" % (
				"Reintenta de nuevo."
				if error_message.is_empty()
				else error_message
			)
		"dirty":
			return "Hay cambios sin guardar\nPresiona Guardar para conservarlos"
		"saved":
			return "Ultimo guardado: %s" % last_saved_at
		_:
			if last_saved_at == "sin datos" or last_saved_at.is_empty():
				return (
					"Todavia no hay guardado local\n"
					+ "Usa Guardar cuando quieras conservar este avance"
				)
			return "Ultimo guardado: %s" % last_saved_at
 