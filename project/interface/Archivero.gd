extends Node2D

const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")

@onready var background = $Background
@onready var profile_overlay: Control = $ProfileOverlayLayer/ProfileOverlay
@onready var profile_toggle_button: Button = $ProfileOverlayLayer/ProfileToggleButton
@onready var close_profile_button: Button = $ProfileOverlayLayer/ProfileOverlay/CloseProfileButton
@onready var avatar_preview: TextureRect = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/AvatarPreview
@onready var avatar_state: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/AvatarState
@onready var username_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/UsernameLabel
@onready var email_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/EmailLabel
@onready var age_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/AgeLabel
@onready var progress_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SummaryPanel/MarginContainer/SummaryContent/ProgressLabel
@onready var save_status_label: Label = $ProfileOverlayLayer/ProfileOverlay/SessionPanel/MarginContainer/ProfileContent/SaveStatusLabel
@onready var history_text: RichTextLabel = $ProfileOverlayLayer/ProfileOverlay/HistoryPanel/MarginContainer/HistoryContent/HistoryText

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
	_sync_profile_overlay_state()
	_refresh_dashboard()


func _refresh_dashboard() -> void:
	var profile := SaveManager.get_current_user_profile()
	var summary := Global.get_progress_summary()

	username_label.text = "Perfil: %s" % profile.get("username", SaveManager.DEFAULT_PROFILE_NAME)
	email_label.text = "Mail: %s" % profile.get("email", "-")
	age_label.text = "Edad: %s" % str(profile.get("age", "-"))
	progress_label.text = "Avance total: %d/%d capitulos\nCeliaquia: %d/6\nVeganismo: %d/6\nVeganismo + Celiaquia: %d/6" % [
		summary.get("total", 0),
		summary.get("max_total", 18),
		summary.get("celiaquia", 0),
		summary.get("veganismo", 0),
		summary.get("veganismo_celiaquia", 0)
	]
	save_status_label.text = _format_save_status(SaveManager.get_save_status())
	_update_toggle_button_state(SaveManager.get_save_status())

	var avatar_texture := SaveManager.get_current_user_avatar_texture()
	avatar_preview.texture = avatar_texture
	avatar_state.text = "Foto local cargada" if avatar_texture != null else "Sin foto disponible"

	var history := SaveManager.get_current_user_history()
	if history.is_empty():
		history_text.text = "Todavia no hay eventos guardados."
		_sync_profile_overlay_state()
		return

	var lines: Array[String] = []
	for entry in history:
		lines.append("%s | %s" % [entry.get("timestamp", ""), entry.get("message", "")])
	history_text.text = "\n".join(lines)
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
	var loaded_from := _format_save_source(str(status.get("last_loaded_from", "default")))
	var recovered_from := str(status.get("recovered_from", ""))
	var error_message := str(status.get("last_error", ""))

	match state:
		"error":
			return "Estado del save: error\n%s" % ("Reintenta guardar." if error_message.is_empty() else error_message)
		"recovered":
			return "Save recuperado desde %s\nUltimo guardado: %s" % [_format_save_source(recovered_from), last_saved_at]
		"dirty":
			return "Hay cambios pendientes\nFuente cargada: %s" % loaded_from
		"saved":
			return "Guardado OK: %s\nMotivo: %s" % [last_saved_at, reason]
		_:
			return "Ultimo guardado: %s\nFuente cargada: %s" % [last_saved_at, loaded_from]


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
			return "save principal"
		"temp":
			return "archivo temporal"
		"backup":
			return "backup"
		_:
			return "estado nuevo"


func _on_save_manager_changed(status: Dictionary) -> void:
	var state := str(status.get("state", ""))
	if state == "saved" or state == "recovered":
		_show_saved_state()
	_refresh_dashboard()


func _on_save_manager_profile_changed(_profile: Dictionary) -> void:
	_refresh_dashboard()


func _set_profile_overlay_visible(visible: bool) -> void:
	profile_overlay.visible = visible
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


func _update_toggle_button_state(save_status: Dictionary) -> void:
	var tooltip_lines := ["guardado de partida"]
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	if not last_saved_at.is_empty():
		tooltip_lines.append("Ultimo guardado: %s" % last_saved_at)
	if SaveManager.can_resume_game():
		tooltip_lines.append("Retoma %s" % SaveManager.get_resume_hint())
	profile_toggle_button.tooltip_text = "\n".join(tooltip_lines)


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
