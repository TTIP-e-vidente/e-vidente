extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const DEBUG_TOGGLE_PROGRESS_OVERLAY_KEY := KEY_F6

@export_group("Debug Demo")
@export var debug_force_progress_overlay := false

# Root scene nodes
var background_music_player: AudioStreamPlayer2D
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
var profile_streak_badge: StreakBadge
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
	_cache_root_nodes()
	_cache_overlay_nodes()
	_cache_profile_content_nodes()
	_configure_static_ui()
	_connect_streak_badge()
	_connect_save_manager_signals()
	background_music_player.play()
	_refresh_profile_overlay()
	_apply_debug_demo_flags.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_force_progress_overlay:
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == DEBUG_TOGGLE_PROGRESS_OVERLAY_KEY:
		_update_overlay_visibility(not profile_overlay.visible)


func _exit_tree() -> void:
	_disconnect_save_manager_signals()
	if is_instance_valid(background_music_player):
		background_music_player.stop()
		background_music_player.stream = null


func _cache_root_nodes() -> void:
	background_music_player = $Background as AudioStreamPlayer2D
	reset_progress_dialog = $ResetProgressDialog as ConfirmationDialog
	mode_selection_streak_badge = $CanvasLayer/ModeSelectionStreakBadge


func _cache_overlay_nodes() -> void:
	var overlay_layer := $ProfileOverlayLayer as CanvasLayer
	profile_toggle_button = overlay_layer.get_node("ProfileToggleButton") as Button
	profile_overlay = overlay_layer.get_node("ProfileOverlay") as Control
	close_profile_button = profile_overlay.get_node("CloseProfileButton") as Button
	profile_summary_panel = profile_overlay.get_node("SessionPanel") as PanelContainer
	profile_history_panel = profile_overlay.get_node("HistoryPanel") as PanelContainer


func _cache_profile_content_nodes() -> void:
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
	profile_streak_badge = info_column.get_node("StreakBadge") as StreakBadge
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


func _configure_static_ui() -> void:
	if profile_toggle_button.has_method("set_label_text"):
		profile_toggle_button.call("set_label_text", "Mi progreso")
	else:
		profile_toggle_button.text = "Mi progreso"
	_set_save_icon(SAVE_ICON_IDLE)

	reset_progress_button.text = "Reiniciar progreso"
	reset_progress_dialog.title = "Reiniciar progreso"
	reset_progress_dialog.dialog_text = (
		"Esto borrara el avance guardado, el historial y las partidas retomables "
		+ "de este dispositivo. El perfil visible se conserva."
	)
	reset_progress_dialog.get_ok_button().text = "Reiniciar"

	_update_history_view_visibility(false)
	_sync_overlay_button_visibility()


func _connect_streak_badge() -> void:
	if mode_selection_streak_badge == null or not mode_selection_streak_badge.has_signal("pressed"):
		return
	var callback := Callable(self, "_on_mode_selection_streak_badge_pressed")
	if not mode_selection_streak_badge.is_connected("pressed", callback):
		mode_selection_streak_badge.connect("pressed", callback)


func _refresh_profile_overlay() -> void:
	var username: String = SaveManager.get_current_user_name()
	username_label.text = username
	var email: String = SaveManager.get_current_user_email()
	email_label.text = "Mail: %s" % (email if not email.is_empty() else "sin dato")
	var age: int = SaveManager.get_current_user_age()
	age_label.text = "Edad: %s" % (str(age) if age > 0 else "sin dato")

	# Progreso
	var summary_text := Global.format_progress_summary_text(
		Global.get_progress_summary()
	).strip_edges()
	progress_summary_label.text = (
		summary_text
		if not summary_text.is_empty()
		else "Todavia no hay capitulos completos"
	)

	# Racha
	if (
		is_instance_valid(mode_selection_streak_badge)
		and mode_selection_streak_badge.has_method("render")
	):
		mode_selection_streak_badge.call("render")
	if is_instance_valid(profile_streak_badge):
		profile_streak_badge.render()

	# Estado de guardado
	save_status_label.text = _format_save_status()
	var last_saved_at := SaveManager.get_last_saved_at()
	var tooltip := "Abrir guardado local"
	if not last_saved_at.is_empty():
		tooltip += "\nUltimo guardado: %s" % last_saved_at
	profile_toggle_button.tooltip_text = tooltip

	# Reanudar
	var can_resume: bool = SaveManager.can_resume_current_save()
	resume_now_button.visible = can_resume
	resume_now_button.disabled = not can_resume
	resume_hint_label.text = (
		"Retoma en %s" % SaveManager.get_current_resume_hint()
		if can_resume
		else "Todavia no hay un punto guardado"
	)

	# Avatar
	var avatar_texture: Texture2D = SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state_label.text = "Avatar listo" if avatar_texture != null else "Avatar opcional"

	# Historial
	var history_entries: Array = SaveManager.get_current_save_history()
	history_log_label.text = (
		_build_history_log_text(history_entries)
		if not history_entries.is_empty()
		else "Todavia no hay actividad guardada."
	)

	_sync_overlay_button_visibility()


func _sync_overlay_button_visibility() -> void:
	profile_toggle_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible

func _connect_save_manager_signals() -> void:
	SaveManager.save_status_changed.connect(_on_save_manager_changed)
	SaveManager.progress_loaded.connect(_on_save_manager_profile_changed)
	SaveManager.progress_saved.connect(_on_save_manager_profile_changed)
	SaveManager.user_registered.connect(_on_save_manager_profile_changed)


func _disconnect_save_manager_signals() -> void:
	SaveManager.save_status_changed.disconnect(_on_save_manager_changed)
	SaveManager.progress_loaded.disconnect(_on_save_manager_profile_changed)
	SaveManager.progress_saved.disconnect(_on_save_manager_profile_changed)
	SaveManager.user_registered.disconnect(_on_save_manager_profile_changed)

func _on_save_manager_changed(status: Dictionary) -> void:
	var save_state: String = str(status.get("state", ""))
	if save_state == "saved" or save_state == "recovered":
		_flash_saved_icon_briefly()
	_refresh_profile_overlay()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_profile_overlay()


func _on_profile_toggle_button_pressed() -> void:
	_update_overlay_visibility(true)


func _on_close_profile_button_pressed() -> void:
	_update_overlay_visibility(false)


func _on_profile_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_overlay_visibility(false)


func _on_atras_pressed() -> void:
	SaveManager.save_progress_to_disk()
	GameSceneRouter.go_to_main_menu(get_tree())


func _on_mode_selection_streak_badge_pressed() -> void:
	_update_overlay_visibility(false)
	GameSceneRouter.go_to_streak(get_tree(), ARCHIVERO_SCENE)


func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()


func _on_resume_now_button_pressed() -> void:
	if not SaveManager.can_resume_current_save():
		return
	_update_overlay_visibility(false)
	var resume_state: Dictionary = SaveManager.reload_from_disk_and_get_resume()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_editar_perfil_pressed() -> void:
	SaveManager.save_progress_to_disk()
	get_tree().root.set_meta(
		PROFILE_RETURN_SCENE_META,
		ARCHIVERO_SCENE
	)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_history_toggle_button_pressed() -> void:
	_update_history_view_visibility(not profile_history_panel.visible)


func _on_history_close_button_pressed() -> void:
	_update_history_view_visibility(false)


func _on_reset_progress_button_pressed() -> void:
	reset_progress_dialog.popup_centered(Vector2i(440, 220))


func _on_reset_progress_dialog_confirmed() -> void:
	_update_history_view_visibility(false)
	SaveManager.reset_all_progress()
	_refresh_profile_overlay()


func _update_overlay_visibility(overlay_visible: bool) -> void:
	profile_overlay.visible = overlay_visible
	_update_history_view_visibility(false)
	_sync_overlay_button_visibility()
	if overlay_visible:
		_refresh_profile_overlay()


func _update_history_view_visibility(history_visible: bool) -> void:
	profile_summary_panel.visible = not history_visible
	profile_history_panel.visible = history_visible
	history_toggle_button.text = (
		"Volver al resumen"
		if history_visible
		else "Ver historial"
	)


func _flash_saved_icon_briefly() -> void:
	var save_failed := SaveManager.has_save_error()
	var nothing_was_saved := SaveManager.get_last_saved_reason().is_empty()
	if save_failed or nothing_was_saved:
		_set_save_icon(SAVE_ICON_IDLE)
		return

	_save_icon_feedback_revision += 1
	var this_revision := _save_icon_feedback_revision
	_set_save_icon(SAVE_ICON_OK)
	_revert_save_icon_after_delay(this_revision)


func _revert_save_icon_after_delay(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != _save_icon_feedback_revision:
		return
	_set_save_icon(SAVE_ICON_IDLE)


func _set_save_icon(icon: Texture2D) -> void:
	if profile_toggle_button == null or not is_instance_valid(profile_toggle_button):
		return
	if profile_toggle_button.has_method("set_status_icon"):
		profile_toggle_button.call("set_status_icon", icon)
		return
	profile_toggle_button.icon = icon


func _build_history_log_text(history: Array) -> String:
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


func _format_save_status() -> String:
	var state := SaveManager.get_current_save_state()
	var last_saved_at := SaveManager.get_last_saved_at()
	if last_saved_at.is_empty():
		last_saved_at = "sin datos"
	var error_message := SaveManager.get_last_save_error()
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


func _apply_debug_demo_flags() -> void:
	if debug_force_progress_overlay:
		_update_overlay_visibility(true)
 