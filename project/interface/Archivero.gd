extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ArchiveroUiHelperScript := preload("res://interface/helpers/ArchiveroUiHelper.gd")

@onready var background = $Background
@onready var profile_overlay: Control = $ProfileOverlayLayer/ProfileOverlay
@onready var profile_toggle_button: Button = $ProfileOverlayLayer/ProfileToggleButton
@onready var close_profile_button: Button = $ProfileOverlayLayer/ProfileOverlay/CloseProfileButton
@onready var session_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/SessionPanel
@onready var history_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/HistoryPanel
@onready var profile_content: Control = (
	$ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent
)
@onready var summary_content: Control = (
	profile_content.get_node("SummaryPanel/MarginContainer/SummaryContent") as Control
)
@onready var secondary_actions_row: HBoxContainer = (
	profile_content.get_node("SecondaryActionsRow") as HBoxContainer
)
@onready var status_row: HBoxContainer = (
	profile_content.get_node("StatusRow") as HBoxContainer
)
@onready var history_content: Control = (
	$ProfileOverlayLayer/ProfileOverlay/HistoryPanel/MarginContainer/HistoryContent
)
@onready var history_toggle_button: Button = (
	secondary_actions_row.get_node("HistoryToggleButton") as Button
)
@onready var reset_progress_button: Button = (
	secondary_actions_row.get_node("ResetProgressButton") as Button
)
@onready var reset_progress_dialog: ConfirmationDialog = $ResetProgressDialog
@onready var avatar_preview: TextureRect = (
	summary_content.get_node(
		"AvatarColumn/AvatarFrame/MarginContainer/AvatarPreview"
	) as TextureRect
)
@onready var avatar_state: Label = (
	summary_content.get_node("AvatarColumn/AvatarState") as Label
)
@onready var username_label: Label = (
	summary_content.get_node("InfoColumn/UsernameLabel") as Label
)
@onready var email_label: Label = (
	summary_content.get_node("InfoColumn/MetaRow/EmailBadge/MarginContainer/EmailLabel") as Label
)
@onready var age_label: Label = (
	summary_content.get_node("InfoColumn/MetaRow/AgeBadge/MarginContainer/AgeLabel") as Label
)
@onready var progress_label: Label = (
	summary_content.get_node("InfoColumn/ProgressPanel/MarginContainer/ProgressLabel") as Label
)
@onready var save_status_label: Label = (
	status_row.get_node("SaveCard/MarginContainer/SaveStatusLabel") as Label
)
@onready var resume_hint_label: Label = (
	status_row.get_node("ResumeCard/MarginContainer/ResumeContent/ResumeHintLabel") as Label
)
@onready var resume_now_button: Button = (
	status_row.get_node("ResumeCard/MarginContainer/ResumeContent/ResumeNowButton") as Button
)
@onready var history_text: RichTextLabel = (
	history_content.get_node("HistoryBody/MarginContainer/HistoryText") as RichTextLabel
)

var start_position
var archive_highlighted = false

const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

var save_feedback_revision := 0
var _ui_helper = ArchiveroUiHelperScript.new()

func _ready():
	background.play()
	_connect_save_manager_signals()
	profile_toggle_button.icon = SAVE_ICON_IDLE
	profile_toggle_button.text = "Mi progreso"
	reset_progress_dialog.title = "Reiniciar progreso"
	reset_progress_dialog.dialog_text = (
		"Esto borrara el avance guardado, el historial y las partidas retomables "
		+ "de este dispositivo. El perfil visible se conserva."
	)
	reset_progress_dialog.get_ok_button().text = "Reiniciar"
	history_panel.visible = false
	history_toggle_button.text = "Ver historial"
	reset_progress_button.text = "Reiniciar progreso"
	_sync_profile_overlay_state()
	_refresh_dashboard()


func _refresh_dashboard() -> void:
	var profile := SaveManager.get_current_user_profile()
	var summary := Global.get_progress_summary()
	var save_status := SaveManager.get_save_status()
	var username := str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)).strip_edges()

	username_label.text = username if not username.is_empty() else SaveManager.DEFAULT_PROFILE_NAME
	email_label.text = "Mail: %s" % _ui_helper.format_optional_text(str(profile.get("email", "")))
	age_label.text = "Edad: %s" % _ui_helper.format_optional_number(int(profile.get("age", 0)))
	progress_label.text = Global.format_progress_summary_text(summary)
	save_status_label.text = _ui_helper.format_save_status(save_status)
	var can_resume := SaveManager.can_resume_current_save()
	resume_hint_label.text = _ui_helper.format_resume_hint_label(
		can_resume,
		SaveManager.get_current_resume_hint()
	)
	resume_now_button.visible = can_resume
	resume_now_button.disabled = not can_resume
	_update_toggle_button_state(save_status)

	var avatar_texture := SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state.text = "Avatar listo" if avatar_texture != null else "Avatar opcional"

	var history := SaveManager.get_current_save_history()
	if history.is_empty():
		history_text.text = "Todavia no hay actividad guardada."
		_sync_profile_overlay_state()
		return

	history_text.text = _format_history_text(history)
	_sync_profile_overlay_state()

func _connect_save_manager_signals() -> void:
	if not SaveManager.save_status_changed.is_connected(_on_save_manager_changed):
		SaveManager.save_status_changed.connect(_on_save_manager_changed)
	if not SaveManager.progress_loaded.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_loaded.connect(_on_save_manager_profile_changed)
	if not SaveManager.progress_saved.is_connected(_on_save_manager_profile_changed):
		SaveManager.progress_saved.connect(_on_save_manager_profile_changed)
	if not SaveManager.user_registered.is_connected(_on_save_manager_profile_changed):
		SaveManager.user_registered.connect(_on_save_manager_profile_changed)

func _format_history_text(history: Array) -> String:
	var lines: Array[String] = []
	for entry in history:
		if not entry is Dictionary:
			continue
		lines.append("%s\n%s" % [entry.get("timestamp", ""), entry.get("message", "")])
	return "\n\n".join(lines)

func _on_save_manager_changed(status: Dictionary) -> void:
	var state := str(status.get("state", ""))
	if state == "saved" or state == "recovered":
		_show_saved_state()
	_refresh_dashboard()

func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_dashboard()

func _set_profile_overlay_visible(overlay_visible: bool) -> void:
	profile_overlay.visible = overlay_visible
	_set_history_panel_visible(false)
	_sync_profile_overlay_state()
	if overlay_visible:
		_refresh_dashboard()

func _sync_profile_overlay_state() -> void:
	profile_toggle_button.visible = not profile_overlay.visible
	close_profile_button.visible = profile_overlay.visible

func _on_profile_toggle_button_pressed() -> void:
	_set_profile_overlay_visible(true)

func _on_close_profile_button_pressed() -> void:
	_set_profile_overlay_visible(false)

func _on_profile_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_profile_overlay_visible(false)
	
func _on_mouse_entered():
	$Anim.play("select")
	archive_highlighted = true

func _on_mouse_exited():
	$Anim.play("deselect")
	archive_highlighted = false

func _on_atrás_pressed():
	SaveManager.save_current_user_progress()
	GameSceneRouter.go_to_main_menu(get_tree())

func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()


func _on_resume_now_button_pressed() -> void:
	if not SaveManager.can_resume_current_save():
		return
	_set_profile_overlay_visible(false)
	var resume_state: Dictionary = SaveManager.load_current_save_and_get_resume_state(false)
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)

func _on_editar_perfil_pressed() -> void:
	SaveManager.save_current_user_progress()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE)
	GameSceneRouter.go_to_profile_editor(get_tree())

func _on_history_toggle_button_pressed() -> void:
	_set_history_panel_visible(not history_panel.visible)

func _on_history_close_button_pressed() -> void:
	_set_history_panel_visible(false)

func _on_reset_progress_button_pressed() -> void:
	reset_progress_dialog.popup_centered(Vector2i(440, 220))

func _on_reset_progress_dialog_confirmed() -> void:
	_set_history_panel_visible(false)
	SaveManager.reset_all_progress()
	_refresh_dashboard()

func _update_toggle_button_state(save_status: Dictionary) -> void:
	profile_toggle_button.tooltip_text = _ui_helper.build_toggle_tooltip(save_status)
	profile_toggle_button.text = "Mi progreso"

func _show_saved_state() -> void:
	var save_status := SaveManager.get_save_status()
	if str(save_status.get("state", "")) == "error":
		profile_toggle_button.icon = SAVE_ICON_IDLE
		return
	if str(save_status.get("last_saved_reason", "")) == "":
		profile_toggle_button.icon = SAVE_ICON_IDLE
		return
	save_feedback_revision += 1
	var revision := save_feedback_revision
	profile_toggle_button.icon = SAVE_ICON_OK
	_reset_saved_icon_async(revision)

func _reset_saved_icon_async(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != save_feedback_revision:
		return
	profile_toggle_button.icon = SAVE_ICON_IDLE

func _set_history_panel_visible(history_visible: bool) -> void:
	session_panel.visible = not history_visible
	history_panel.visible = history_visible
	history_toggle_button.text = "Volver al resumen" if history_visible else "Ver historial"
