extends Node2D

## --- Recursos ---

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK   := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter         := preload("res://niveles/GameSceneRouter.gd")
const ArchiveroUiHelperScript := preload("res://interface/helpers/ArchiveroUiHelper.gd")

const PROFILE_RETURN_SCENE_META       := "profile_return_scene"
const ARCHIVERO_SCENE                 := "res://interface/archivero.tscn"
const DEBUG_TOGGLE_PROGRESS_OVERLAY_KEY := KEY_F6

## --- Debug ---

@export_group("Debug Demo")
@export var debug_force_progress_overlay := false

## --- Nodos ---

@onready var background: AudioStreamPlayer2D = $Background
@onready var profile_overlay: Control = $ProfileOverlayLayer/ProfileOverlay
@onready var open_profile_button: Button = $ProfileOverlayLayer/ProfileToggleButton
@onready var close_profile_button: Button = $ProfileOverlayLayer/ProfileOverlay/CloseProfileButton
@onready var summary_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/SessionPanel
@onready var history_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/HistoryPanel
@onready var history_toggle_button: Button = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SecondaryActionsRow/HistoryToggleButton
)
@onready var reset_progress_button: Button = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SecondaryActionsRow/ResetProgressButton
)
@onready var reset_progress_dialog: ConfirmationDialog = $ResetProgressDialog
@onready var avatar_preview: TextureRect = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/AvatarColumn/AvatarFrame/
	MarginContainer/AvatarPreview
)
@onready var avatar_state_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/AvatarColumn/AvatarState
)
@onready var username_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/InfoColumn/UsernameLabel
)
@onready var email_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/InfoColumn/MetaRow/EmailBadge/
	MarginContainer/EmailLabel
)
@onready var age_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/InfoColumn/MetaRow/AgeBadge/
	MarginContainer/AgeLabel
)
@onready var progress_summary_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/InfoColumn/ProgressLabel
)
@onready var streak_badge: StreakBadge = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	SummaryPanel/MarginContainer/SummaryContent/InfoColumn/StreakBadge
)
@onready var save_status_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	StatusRow/SaveCard/MarginContainer/SaveStatusLabel
)
@onready var resume_hint_label: Label = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	StatusRow/ResumeCard/MarginContainer/ResumeContent/ResumeHintLabel
)
@onready var resume_now_button: Button = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/
	StatusRow/ResumeCard/MarginContainer/ResumeContent/ResumeNowButton
)
@onready var history_log_label: RichTextLabel = (
	$ProfileOverlayLayer/ProfileOverlay/HistoryPanel/MarginContainer/HistoryContent/
	HistoryBody/MarginContainer/HistoryText
)

## --- Estado runtime ---

var _save_icon_feedback_revision := 0
var _archivero_ui_helper         = ArchiveroUiHelperScript.new()

## --- Ciclo de vida ---


func _ready() -> void:
	background.play()
	_connect_save_manager_signals()
	open_profile_button.icon = SAVE_ICON_IDLE
	open_profile_button.text = "Mi progreso"
	reset_progress_button.text = "Reiniciar progreso"
	_set_history_view_visible(false)
	open_profile_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible
	reset_progress_dialog.title = "Reiniciar progreso"
	reset_progress_dialog.dialog_text = (
		"Esto borrara el avance guardado, el historial y las partidas retomables "
		+ "de este dispositivo. El perfil visible se conserva."
	)
	reset_progress_dialog.get_ok_button().text = "Reiniciar"
	_refresh_profile_overlay()
	call_deferred("_apply_debug_demo_flags")


func _unhandled_input(event: InputEvent) -> void:
	if not debug_force_progress_overlay:
		return

	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == DEBUG_TOGGLE_PROGRESS_OVERLAY_KEY:
		_set_profile_overlay_visible(not profile_overlay.visible)


func _exit_tree() -> void:
	_disconnect_save_manager_signals()
	if is_instance_valid(background):
		background.stop()
		background.stream = null


## --- Refresco del overlay de perfil ---

func _refresh_profile_overlay() -> void:
	var profile := SaveManager.get_current_user_profile()
	var save_status := SaveManager.get_save_status()
	var username_text := str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)).strip_edges()
	username_label.text = (
		username_text
		if not username_text.is_empty()
		else SaveManager.DEFAULT_PROFILE_NAME
	)
	email_label.text = "Mail: %s" % _archivero_ui_helper.format_optional_text(
		str(profile.get("email", ""))
	)
	age_label.text = "Edad: %s" % _archivero_ui_helper.format_optional_number(
		int(profile.get("age", 0))
	)

	var progress_summary_text := (
		Global.format_progress_summary_text(Global.get_progress_summary()).strip_edges()
	)
	progress_summary_label.text = (
		"Todavia no hay capitulos completos"
		if progress_summary_text.is_empty()
		else progress_summary_text
	)
	if streak_badge == null or not is_instance_valid(streak_badge):
		pass
	else:
		streak_badge.render()

	save_status_label.text = _archivero_ui_helper.format_save_status(save_status)
	open_profile_button.tooltip_text = _archivero_ui_helper.build_toggle_tooltip(save_status)

	var can_resume := SaveManager.can_resume_current_save()
	resume_hint_label.text = _archivero_ui_helper.format_resume_hint_label(
		can_resume,
		SaveManager.get_current_resume_hint()
	)
	resume_now_button.visible = can_resume
	resume_now_button.disabled = not can_resume

	var avatar_texture := SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state_label.text = (
		"Avatar listo"
		if avatar_texture != null
		else "Avatar opcional"
	)

	var history_entries := SaveManager.get_current_save_history()
	history_log_label.text = (
		"Todavia no hay actividad guardada."
		if history_entries.is_empty()
		else _build_history_log_text(history_entries)
	)

	open_profile_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible


## --- Señales de SaveManager ---

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


## --- Handlers de UI ---

func _on_save_manager_changed(status: Dictionary) -> void:
	var save_state := str(status.get("state", ""))
	if save_state == "saved" or save_state == "recovered":
		_show_saved_icon_feedback()
	_refresh_profile_overlay()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_profile_overlay()


func _set_profile_overlay_visible(overlay_visible: bool) -> void:
	profile_overlay.visible = overlay_visible
	_set_history_view_visible(false)
	open_profile_button.visible = not overlay_visible
	close_profile_button.visible = overlay_visible
	if overlay_visible:
		_refresh_profile_overlay()


func _apply_debug_demo_flags() -> void:
	if debug_force_progress_overlay:
		_set_profile_overlay_visible(true)


func _on_profile_toggle_button_pressed() -> void:
	_set_profile_overlay_visible(true)


func _on_close_profile_button_pressed() -> void:
	_set_profile_overlay_visible(false)


func _on_profile_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_profile_overlay_visible(false)


func _on_mouse_entered() -> void:
	$Anim.play("select")


func _on_mouse_exited() -> void:
	$Anim.play("deselect")


func _on_atras_pressed() -> void:
	SaveManager.persist_runtime_progress_to_current_save()
	GameSceneRouter.go_to_main_menu(get_tree())


func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()


func _on_resume_now_button_pressed() -> void:
	if not SaveManager.can_resume_current_save():
		return
	_set_profile_overlay_visible(false)
	var resume_state: Dictionary = SaveManager.reload_current_save_and_get_resume_state()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_editar_perfil_pressed() -> void:
	SaveManager.persist_runtime_progress_to_current_save()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())


func _on_history_toggle_button_pressed() -> void:
	_set_history_view_visible(not history_panel.visible)


func _on_history_close_button_pressed() -> void:
	_set_history_view_visible(false)


func _on_reset_progress_button_pressed() -> void:
	reset_progress_dialog.popup_centered(Vector2i(440, 220))


func _on_reset_progress_dialog_confirmed() -> void:
	_set_history_view_visible(false)
	SaveManager.reset_all_progress()
	_refresh_profile_overlay()


func _show_saved_icon_feedback() -> void:
	var save_status := SaveManager.get_save_status()
	if (
		str(save_status.get("state", "")) == "error"
		or str(save_status.get("last_saved_reason", "")) == ""
	):
		open_profile_button.icon = SAVE_ICON_IDLE
		return
	_save_icon_feedback_revision += 1
	var feedback_revision := _save_icon_feedback_revision
	open_profile_button.icon = SAVE_ICON_OK
	_reset_saved_icon_after_delay(feedback_revision)


func _reset_saved_icon_after_delay(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != _save_icon_feedback_revision:
		return
	open_profile_button.icon = SAVE_ICON_IDLE


func _set_history_view_visible(history_visible: bool) -> void:
	summary_panel.visible = not history_visible
	history_panel.visible = history_visible
	history_toggle_button.text = (
		"Volver al resumen"
		if history_visible
		else "Ver historial"
	)
