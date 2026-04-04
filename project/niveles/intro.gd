extends Node2D
@onready var background = $Background
@onready var play_panel: PanelContainer = $PlayPanel
@onready var save_button: Button = $SaveButton
@onready var save_feedback_label: Label = $SaveFeedbackLabel
@onready var play_panel_subtitle: Label = $PlayPanel/MarginContainer/Content/Subtitle
@onready var new_game_button: Button = $PlayPanel/MarginContainer/Content/NewGameButton
@onready var load_game_button: Button = $PlayPanel/MarginContainer/Content/LoadGameButton

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-base-datos.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-base-datos-ok.svg")
const NEW_GAME_BUTTON_LABEL := "Nueva partida"
const NEW_GAME_BUTTON_CONFIRM_LABEL := "Confirmar nueva partida"

var save_feedback_revision := 0
var new_game_confirmation_revision := 0
var is_new_game_confirmation_pending := false

func _ready():
	background.play()
	_connect_save_manager_signals()
	save_button.icon = SAVE_ICON_IDLE
	_set_play_panel_visible(false)
	save_feedback_label.text = ""
	_refresh_play_panel_copy()
	_update_save_button_state(SaveManager.get_save_status())


func _on_start_pressed():
	save_feedback_label.text = ""
	_refresh_play_panel_copy()
	_set_play_panel_visible(true)


func _on_load_game_pressed() -> void:
	_set_new_game_confirmation_state(false)
	if not SaveManager.can_resume_game():
		save_feedback_label.text = "Todavia no hay una partida para cargar."
		_set_play_panel_visible(false)
		return
	var resume_state := SaveManager.load_progress_and_get_resume_state(false)
	_set_play_panel_visible(false)
	get_tree().change_scene_to_file(str(resume_state.get("scene_path", ARCHIVERO_SCENE)))


func _on_new_game_pressed() -> void:
	if SaveManager.can_resume_game() and not is_new_game_confirmation_pending:
		_set_new_game_confirmation_state(true)
		save_feedback_label.text = "Esto reemplaza la partida actual. Volve a tocar para confirmar."
		_schedule_new_game_confirmation_reset()
		return

	_set_new_game_confirmation_state(false)
	if not SaveManager.start_new_game():
		save_feedback_label.text = "No se pudo iniciar una nueva partida."
		return
	get_tree().change_scene_to_file(ARCHIVERO_SCENE)


func _on_close_play_panel_pressed() -> void:
	_set_play_panel_visible(false)


func _on_save_pressed() -> void:
	SaveManager.record_manual_save()
	var save_status := SaveManager.get_save_status()
	var state := str(save_status.get("state", ""))
	if state == "error":
		save_feedback_label.text = "No se pudo guardar."
		save_button.icon = SAVE_ICON_IDLE
	else:
		save_feedback_label.text = _format_saved_message(save_status)
		_show_saved_state()
	_refresh_play_panel_copy()

func _on_opciones_pressed():
	get_tree().change_scene_to_file("res://interface/opciones.tscn")

func _on_salir_pressed():
	get_tree().quit()


func _set_play_panel_visible(visible: bool) -> void:
	play_panel.visible = visible
	if not visible:
		_set_new_game_confirmation_state(false)
		return
	if SaveManager.can_resume_game():
		load_game_button.grab_focus()
		return
	new_game_button.grab_focus()


func _refresh_play_panel_copy() -> void:
	if not play_panel.visible:
		_set_new_game_confirmation_state(false)
	if SaveManager.can_resume_game():
		play_panel_subtitle.text = "Retoma %s o empeza una partida nueva." % SaveManager.get_resume_hint()
		load_game_button.disabled = false
		_update_save_button_state(SaveManager.get_save_status())
		return

	play_panel_subtitle.text = "Empeza de cero. La opcion de cargar se activa cuando ya exista una partida."
	load_game_button.disabled = true
	_update_save_button_state(SaveManager.get_save_status())


func _format_saved_message(save_status: Dictionary) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	if saved_time.is_empty():
		return "Guardado listo"
	return "Guardado %s" % saved_time


func _connect_save_manager_signals() -> void:
	if not SaveManager.save_status_changed.is_connected(_on_save_status_changed):
		SaveManager.save_status_changed.connect(_on_save_status_changed)


func _on_save_status_changed(save_status: Dictionary) -> void:
	_update_save_button_state(save_status)


func _update_save_button_state(save_status: Dictionary) -> void:
	var tooltip_lines := ["guardado de partida"]
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	if not last_saved_at.is_empty():
		tooltip_lines.append("Ultimo guardado: %s" % last_saved_at)
	if SaveManager.can_resume_game():
		tooltip_lines.append("Retoma %s" % SaveManager.get_resume_hint())
	save_button.tooltip_text = "\n".join(tooltip_lines)


func _show_saved_state() -> void:
	save_feedback_revision += 1
	var revision := save_feedback_revision
	save_button.icon = SAVE_ICON_OK
	_reset_saved_icon_async(revision)


func _set_new_game_confirmation_state(pending: bool) -> void:
	is_new_game_confirmation_pending = pending
	new_game_button.text = NEW_GAME_BUTTON_CONFIRM_LABEL if pending else NEW_GAME_BUTTON_LABEL


func _schedule_new_game_confirmation_reset() -> void:
	new_game_confirmation_revision += 1
	var revision := new_game_confirmation_revision
	_reset_new_game_confirmation_async(revision)


func _reset_new_game_confirmation_async(revision: int) -> void:
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree() or revision != new_game_confirmation_revision or not is_new_game_confirmation_pending:
		return
	_set_new_game_confirmation_state(false)


func _reset_saved_icon_async(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != save_feedback_revision:
		return
	save_button.icon = SAVE_ICON_IDLE



