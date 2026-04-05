extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")

@onready var background = $Background
@onready var profile_overlay: Control = $ProfileOverlayLayer/ProfileOverlay
@onready var profile_toggle_button: Button = $ProfileOverlayLayer/ProfileToggleButton
@onready var close_profile_button: Button = $ProfileOverlayLayer/ProfileOverlay/CloseProfileButton
@onready var session_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/SessionPanel
@onready var history_panel: PanelContainer = $ProfileOverlayLayer/ProfileOverlay/HistoryPanel
@onready var history_toggle_button: Button = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/HistoryToggleButton
@onready var avatar_preview: TextureRect = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/AvatarColumn/AvatarFrame/MarginContainer/AvatarPreview
@onready var avatar_state: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/AvatarColumn/AvatarState
@onready var username_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/UsernameLabel
@onready var email_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/MetaRow/EmailBadge/MarginContainer/EmailLabel
@onready var age_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/MetaRow/AgeBadge/MarginContainer/AgeLabel
@onready var progress_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/InfoColumn/ProgressPanel/MarginContainer/ProgressLabel
@onready var save_status_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/SaveCard/MarginContainer/SaveStatusLabel
@onready var resume_hint_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/StatusRow/ResumeCard/MarginContainer/ResumeHintLabel
@onready var history_text: RichTextLabel = $ProfileOverlayLayer/ProfileOverlay/HistoryPanel/MarginContainer/HistoryContent/HistoryBody/MarginContainer/HistoryText

var start_position
var archive_highlighted = false

const PROFILE_SCENE := "res://interface/auth.tscn"
const PROFILE_RETURN_SCENE_META := "profile_return_scene"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

var save_feedback_revision := 0

func _ready():
	background.play()
	_connect_save_manager_signals()
	profile_toggle_button.icon = SAVE_ICON_IDLE
	profile_toggle_button.text = "Mi progreso"
	history_panel.visible = false
	history_toggle_button.text = "Ver historial"
	_sync_profile_overlay_state()
	_refresh_dashboard()


func _refresh_dashboard() -> void:
	var profile := SaveManager.get_current_user_profile()
	var summary := Global.get_progress_summary()
	var save_status := SaveManager.get_save_status()
	var username := str(profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)).strip_edges()
	var email := _format_optional_text(str(profile.get("email", "")))
	var age := _format_optional_number(int(profile.get("age", 0)))

	username_label.text = username if not username.is_empty() else SaveManager.DEFAULT_PROFILE_NAME
	email_label.text = "Mail: %s" % email
	age_label.text = "Edad: %s" % age
	progress_label.text = "%d de %d capitulos completos\nCeliaquia %d/6 | Veganismo %d/6 | Mixto %d/6" % [
		summary.get("total", 0),
		summary.get("max_total", 18),
		summary.get("celiaquia", 0),
		summary.get("veganismo", 0),
		summary.get("veganismo_celiaquia", 0)
	]
	save_status_label.text = _format_save_status(save_status)
	resume_hint_label.text = _format_resume_hint_label()
	_update_toggle_button_state(save_status)

	var avatar_texture := SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state.text = "Avatar listo" if avatar_texture != null else "Avatar opcional"

	var history := SaveManager.get_current_user_history()
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


func _format_save_status(status: Dictionary) -> String:
	var state := str(status.get("state", "idle"))
	var last_saved_at := str(status.get("last_saved_at", "sin datos"))
	var reason := _format_save_reason(str(status.get("last_saved_reason", "")))
	var recovered_from := str(status.get("recovered_from", ""))
	var error_message := str(status.get("last_error", ""))

	match state:
		"error":
			return "No se pudo guardar.\n%s" % ("Reintenta de nuevo." if error_message.is_empty() else error_message)
		"recovered":
			return "Se recupero una copia desde %s\nUltimo guardado: %s" % [_format_save_source(recovered_from), last_saved_at]
		"dirty":
			return "Hay cambios sin guardar\nPresiona Guardar para conservarlos"
		"saved":
			return "Ultimo guardado: %s\n%s" % [last_saved_at, reason]
		_:
			if last_saved_at == "sin datos" or last_saved_at.is_empty():
				return "Todavia no hay guardado local\nUsa Guardar cuando quieras conservar este avance"
			return "Ultimo guardado: %s\nListo para continuar" % last_saved_at


func _format_history_text(history: Array) -> String:
	var lines: Array[String] = []
	for entry in history:
		if not entry is Dictionary:
			continue
		lines.append("%s\n%s" % [entry.get("timestamp", ""), entry.get("message", "")])
	return "\n\n".join(lines)


func _format_save_reason(reason: String) -> String:
	match reason:
		"profile_updated":
			return "perfil actualizado"
		"new_game":
			return "nueva partida"
		"progress_sync":
			return "sincronizacion de progreso"
		"level_completed":
			return "nivel completado"
		"manual_save":
			return "guardado manual"
		"load_repair":
			return "reparacion al cargar"
		"legacy_migration":
			return "migracion legacy"
		_:
			return "guardado local"


func _format_save_source(source: String) -> String:
	match source:
		"primary":
			return "tu guardado principal"
		"temp":
			return "un guardado temporal"
		"backup":
			return "una copia de respaldo"
		_:
			return "un estado nuevo"


func _format_optional_text(value: String) -> String:
	var clean_value := value.strip_edges()
	if clean_value.is_empty():
		return "sin dato"
	return clean_value


func _format_optional_number(value: int) -> String:
	if value <= 0:
		return "sin dato"
	return str(value)


func _on_save_manager_changed(status: Dictionary) -> void:
	var state := str(status.get("state", ""))
	if state == "saved" or state == "recovered":
		_show_saved_state()
	_refresh_dashboard()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_dashboard()


func _set_profile_overlay_visible(visible: bool) -> void:
	profile_overlay.visible = visible
	_set_history_panel_visible(false)
	_sync_profile_overlay_state()
	if visible:
		_refresh_dashboard()


func _sync_profile_overlay_state() -> void:
	var is_open := profile_overlay.visible
	profile_toggle_button.visible = not is_open
	close_profile_button.visible = is_open


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
	get_tree().change_scene_to_file("res://niveles/intro.tscn")


func _on_guardar_pressed() -> void:
	SaveManager.record_manual_save()


func _on_editar_perfil_pressed() -> void:
	SaveManager.save_current_user_progress()
	get_tree().root.set_meta(PROFILE_RETURN_SCENE_META, ARCHIVERO_SCENE)
	get_tree().change_scene_to_file(PROFILE_SCENE)


func _on_history_toggle_button_pressed() -> void:
	_set_history_panel_visible(not history_panel.visible)


func _on_history_close_button_pressed() -> void:
	_set_history_panel_visible(false)


func _update_toggle_button_state(save_status: Dictionary) -> void:
	var tooltip_lines := ["Abrir guardado local"]
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	if not last_saved_at.is_empty():
		tooltip_lines.append("Ultimo guardado: %s" % last_saved_at)
	profile_toggle_button.tooltip_text = "\n".join(tooltip_lines)
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


func _format_resume_hint_label() -> String:
	if SaveManager.can_resume_game():
		return "Retoma en %s\nSegui desde ese punto cuando quieras." % SaveManager.get_resume_hint()
	return "Todavia no hay un punto guardado\nCuando avances en una partida aparecera aca"


func _set_history_panel_visible(is_visible: bool) -> void:
	session_panel.visible = not is_visible
	history_panel.visible = is_visible
	history_toggle_button.text = "Volver al resumen" if is_visible else "Ver historial"
