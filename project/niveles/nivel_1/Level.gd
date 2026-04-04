extends Node
class_name Level

const TRACK_KEY := "celiaquia"
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")

@onready var background = $Background
@onready var victory = $Victory
@onready var adelante = $Adelante
@onready var ensenanza = $Ensenanza
@onready var meal = $"Globo texto/Meal"
@onready var abstract_condition = $"Globo texto/Condition"
@onready var manager_level = $ManagerLevel
@onready var save_progress_button: Button = $SaveProgressButton
@onready var save_feedback_label: Label = $SaveFeedbackLabel


var is_dragging = false
var save_feedback_revision := 0

func _ready():
	victory.hide()
	adelante.disabled = true
	background.play()
	manager_level.setup(self)
	SaveManager.set_resume_to_level(_get_resume_track_key(), Global.current_level)
	save_progress_button.icon = SAVE_ICON_IDLE
	save_progress_button.tooltip_text = "Guardar progreso en este dispositivo"
	save_feedback_label.text = ""

func _on_atrás_pressed():
	get_tree().change_scene_to_file("res://interface/libro.tscn")

func _victory():
	victory.show()
	victory.play("victory")
	adelante.disabled = false
	ensenanza.show()
	Global.items_level[Global.current_level][6] = true
	SaveManager.record_level_completed(_get_resume_track_key(), Global.current_level)

func _on_adelante_pressed():
	if Global.current_level <= 5: 
		Global.current_level += 1
		get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")
	else:
		get_tree().change_scene_to_file("res://niveles/intro.tscn")


func _on_save_progress_button_pressed() -> void:
	SaveManager.record_manual_save()
	var save_status := SaveManager.get_save_status()
	var state := str(save_status.get("state", ""))
	if state == "error":
		save_feedback_label.text = "No se pudo guardar"
		save_progress_button.icon = SAVE_ICON_IDLE
	else:
		save_feedback_label.text = _format_saved_message(save_status)
		_show_saved_state()


func _get_resume_track_key() -> String:
	return TRACK_KEY


func _format_saved_message(save_status: Dictionary) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	if saved_time.is_empty():
		return "Guardado listo"
	return "Guardado %s" % saved_time


func _show_saved_state() -> void:
	save_feedback_revision += 1
	var revision := save_feedback_revision
	save_progress_button.icon = SAVE_ICON_OK
	_reset_saved_icon_async(revision)


func _reset_saved_icon_async(revision: int) -> void:
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree() or revision != save_feedback_revision:
		return
	save_progress_button.icon = SAVE_ICON_IDLE
