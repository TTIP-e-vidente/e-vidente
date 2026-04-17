extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ArchiveroUiHelperScript := preload("res://interface/helpers/ArchiveroUiHelper.gd")

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const DEBUG_TOGGLE_PROGRESS_OVERLAY_KEY := KEY_F6

@export_group("Debug Demo")
@export var debug_force_progress_overlay := false

var background_music_player: AudioStreamPlayer2D
var hover_animation: AnimationPlayer
var profile_overlay: Control
var profile_toggle_button: Button
var close_profile_button: Button
var profile_summary_panel: PanelContainer
var profile_history_panel: PanelContainer
var history_toggle_button: Button
var reset_progress_button: Button
var reset_progress_dialog: ConfirmationDialog
var avatar_preview: TextureRect
var avatar_state_label: Label
var username_label: Label
var email_label: Label
var age_label: Label
var progress_summary_label: Label
var mode_selection_streak_badge: Node
var profile_streak_badge: StreakBadge
var save_status_label: Label
var resume_hint_label: Label
var resume_now_button: Button
var history_log_label: RichTextLabel

var _save_icon_feedback_revision: int = 0
var _ui_helper = ArchiveroUiHelperScript.new()


func _ready() -> void:
	_cache_ui_nodes()
	_configure_static_ui()
	_connect_save_manager_signals()
	background_music_player.play()
	_refresh_profile_overlay()
	call_deferred("_apply_debug_demo_flags")


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


func _cache_ui_nodes() -> void:
	background_music_player = $Background as AudioStreamPlayer2D
	hover_animation = $Anim as AnimationPlayer
	reset_progress_dialog = $ResetProgressDialog as ConfirmationDialog
	mode_selection_streak_badge = $CanvasLayer/ModeSelectionStreakBadge

	var overlay_layer := $ProfileOverlayLayer as CanvasLayer
	profile_toggle_button = overlay_layer.get_node("ProfileToggleButton") as Button
	profile_overlay = overlay_layer.get_node("ProfileOverlay") as Control
	close_profile_button = profile_overlay.get_node("CloseProfileButton") as Button
	profile_summary_panel = profile_overlay.get_node("SessionPanel") as PanelContainer
	profile_history_panel = profile_overlay.get_node("HistoryPanel") as PanelContainer

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

	history_toggle_button = secondary_actions_row.get_node(
		"HistoryToggleButton"
	) as Button
	reset_progress_button = secondary_actions_row.get_node(
		"ResetProgressButton"
	) as Button
	avatar_preview = summary_content.get_node(
		"AvatarColumn/AvatarFrame/MarginContainer/AvatarPreview"
	) as TextureRect
	avatar_state_label = summary_content.get_node(
		"AvatarColumn/AvatarState"
	) as Label
	username_label = info_column.get_node("UsernameLabel") as Label
	email_label = info_column.get_node(
		"MetaRow/EmailBadge/MarginContainer/EmailLabel"
	) as Label
	age_label = info_column.get_node(
		"MetaRow/AgeBadge/MarginContainer/AgeLabel"
	) as Label
	progress_summary_label = info_column.get_node("ProgressLabel") as Label
	profile_streak_badge = info_column.get_node("StreakBadge") as StreakBadge
	save_status_label = status_row.get_node(
		"SaveCard/MarginContainer/SaveStatusLabel"
	) as Label
	resume_hint_label = resume_content.get_node("ResumeHintLabel") as Label
	resume_now_button = resume_content.get_node("ResumeNowButton") as Button
	history_log_label = history_content.get_node(
		"HistoryBody/MarginContainer/HistoryText"
	) as RichTextLabel


func _configure_static_ui() -> void:
	_set_profile_toggle_button_label("Mi progreso")
	_set_profile_toggle_button_status_icon(SAVE_ICON_IDLE)
	reset_progress_button.text = "Reiniciar progreso"
	_configure_reset_progress_dialog()
	_update_history_view_visibility(false)
	_sync_overlay_button_visibility()


func _configure_reset_progress_dialog() -> void:
	reset_progress_dialog.title = "Reiniciar progreso"
	reset_progress_dialog.dialog_text = (
		"Esto borrara el avance guardado, el historial y las partidas retomables "
		+ "de este dispositivo. El perfil visible se conserva."
	)
	reset_progress_dialog.get_ok_button().text = "Reiniciar"


func _refresh_profile_overlay() -> void:
	var profile: Dictionary = SaveManager.get_current_user_profile()
	var save_status: Dictionary = SaveManager.get_save_status()

	_refresh_profile_identity(profile)
	_refresh_profile_progress()
	_refresh_streak_badges()
	_refresh_save_status(save_status)
	_refresh_resume_state()
	_refresh_avatar_state()
	_refresh_history_state()
	_sync_overlay_button_visibility()


func _refresh_profile_identity(profile: Dictionary) -> void:
	var username_text: String = str(
		profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)
	).strip_edges()
	username_label.text = (
		username_text
		if not username_text.is_empty()
		else SaveManager.DEFAULT_PROFILE_NAME
	)
	email_label.text = "Mail: %s" % _ui_helper.format_optional_text(
		str(profile.get("email", ""))
	)
	age_label.text = "Edad: %s" % _ui_helper.format_optional_number(
		int(profile.get("age", 0))
	)


func _refresh_profile_progress() -> void:
	var progress_summary_text: String = Global.format_progress_summary_text(
		Global.get_progress_summary()
	).strip_edges()
	progress_summary_label.text = (
		"Todavia no hay capitulos completos"
		if progress_summary_text.is_empty()
		else progress_summary_text
	)


func _refresh_save_status(save_status: Dictionary) -> void:
	save_status_label.text = _ui_helper.format_save_status(save_status)
	profile_toggle_button.tooltip_text = _ui_helper.build_toggle_tooltip(save_status)


func _refresh_resume_state() -> void:
	var can_resume: bool = SaveManager.can_resume_current_save()
	resume_hint_label.text = _ui_helper.format_resume_hint_label(
		can_resume,
		SaveManager.get_current_resume_hint()
	)
	resume_now_button.visible = can_resume
	resume_now_button.disabled = not can_resume


func _refresh_avatar_state() -> void:
	var avatar_texture: Texture2D = SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state_label.text = (
		"Avatar listo"
		if avatar_texture != null
		else "Avatar opcional"
	)


func _refresh_history_state() -> void:
	var history_entries: Array = SaveManager.get_current_save_history()
	history_log_label.text = (
		"Todavia no hay actividad guardada."
		if history_entries.is_empty()
		else _build_history_log_text(history_entries)
	)


func _refresh_streak_badges() -> void:
	if (
		mode_selection_streak_badge != null
		and is_instance_valid(mode_selection_streak_badge)
		and mode_selection_streak_badge.has_method("render")
	):
		mode_selection_streak_badge.call("render")
	if profile_streak_badge != null and is_instance_valid(profile_streak_badge):
		profile_streak_badge.render()
	_debug_log_ui_streak_state("refresh_streak_badges")


func _sync_overlay_button_visibility() -> void:
	profile_toggle_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible


func _connect_save_manager_signals() -> void:
	if not SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.connect(_on_save_manager_changed)
	if not SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.connect(_on_save_manager_profile_changed)
	if not SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.connect(_on_save_manager_profile_changed)
	if not SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.connect(_on_save_manager_profile_changed)


func _disconnect_save_manager_signals() -> void:
	if SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.disconnect(_on_save_manager_changed)
	if SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.disconnect(_on_save_manager_profile_changed)
	if SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.disconnect(_on_save_manager_profile_changed)
	if SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.disconnect(_on_save_manager_profile_changed)


func _on_save_manager_changed(status: Dictionary) -> void:
	var save_state: String = str(status.get("state", ""))
	if save_state == "saved" or save_state == "recovered":
		_show_saved_icon_feedback()
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


func _on_mouse_entered() -> void:
	hover_animation.play("select")


func _on_mouse_exited() -> void:
	hover_animation.play("deselect")


func _on_atras_pressed() -> void:
	SaveManager.persist_runtime_progress_to_current_save()
	GameSceneRouter.go_to_main_menu(get_tree())


func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()


func _on_resume_now_button_pressed() -> void:
	if not SaveManager.can_resume_current_save():
		return
	_update_overlay_visibility(false)
	var resume_state: Dictionary = SaveManager.reload_current_save_and_get_resume_state()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_editar_perfil_pressed() -> void:
	SaveManager.persist_runtime_progress_to_current_save()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE)
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


func _show_saved_icon_feedback() -> void:
	var save_status: Dictionary = SaveManager.get_save_status()
	if (
		str(save_status.get("state", "")) == "error"
		or str(save_status.get("last_saved_reason", "")) == ""
	):
		_set_profile_toggle_button_status_icon(SAVE_ICON_IDLE)
		return

	_save_icon_feedback_revision += 1
	var feedback_revision: int = _save_icon_feedback_revision
	_set_profile_toggle_button_status_icon(SAVE_ICON_OK)
	_reset_saved_icon_after_delay(feedback_revision)


func _reset_saved_icon_after_delay(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != _save_icon_feedback_revision:
		return
	_set_profile_toggle_button_status_icon(SAVE_ICON_IDLE)


func _set_profile_toggle_button_label(button_label: String) -> void:
	if profile_toggle_button == null or not is_instance_valid(profile_toggle_button):
		return
	if profile_toggle_button.has_method("set_label_text"):
		profile_toggle_button.call("set_label_text", button_label)
		return
	profile_toggle_button.text = button_label


func _set_profile_toggle_button_status_icon(status_icon: Texture2D) -> void:
	if profile_toggle_button == null or not is_instance_valid(profile_toggle_button):
		return
	if profile_toggle_button.has_method("set_status_icon"):
		profile_toggle_button.call("set_status_icon", status_icon)
		return
	profile_toggle_button.icon = status_icon


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


func _apply_debug_demo_flags() -> void:
	if debug_force_progress_overlay:
		_update_overlay_visibility(true)


func _debug_log_ui_streak_state(checkpoint: String) -> void:
	if not OS.is_debug_build():
		return

	var payload: Dictionary = {
		"checkpoint": checkpoint,
		"streak_state": Global.get_streak_state(),
		"streak_view_model": Global.get_streak_view_model()
	}
	print("[STREAK_DEBUG][UI] %s" % JSON.stringify(payload))
