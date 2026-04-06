extends Node
class_name Level

const TRACK_KEY := "celiaquia"
const SAVE_ICON_IDLE := preload("res://assets-sistema/interfaz/icono-guardar.svg")
const SAVE_ICON_OK := preload("res://assets-sistema/interfaz/icono-guardar-ok.svg")
const SAVE_FEEDBACK_SUCCESS_TITLE_COLOR := Color(0.215686, 0.337255, 0.231373, 1)
const SAVE_FEEDBACK_SUCCESS_BODY_COLOR := Color(0.266667, 0.227451, 0.156863, 0.96)
const SAVE_FEEDBACK_ERROR_TITLE_COLOR := Color(0.568627, 0.184314, 0.141176, 1)
const SAVE_FEEDBACK_ERROR_BODY_COLOR := Color(0.403922, 0.160784, 0.121569, 0.96)

@onready var background: AudioStreamPlayer2D = $Background
@onready var victory = $Victory
@onready var adelante = $Adelante
@onready var ensenanza = $Ensenanza
@onready var meal = $"Globo texto/Meal"
@onready var abstract_condition = $"Globo texto/Condition"
@onready var manager_level: ManagerLevel = $ManagerLevel
@onready var save_progress_button: Button = $SaveProgressButton
@onready var save_feedback_backdrop: PanelContainer = $SaveFeedbackBackdrop
@onready var save_feedback_title: Label = $SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackTitle
@onready var save_feedback_label: Label = $SaveFeedbackBackdrop/SaveFeedbackPadding/SaveFeedbackStack/SaveFeedbackLabel


var is_dragging = false
var save_feedback_timer: Timer

func _ready():
	victory.hide()
	adelante.disabled = true
	background.play()
	manager_level.setup(self)
	SaveManager.set_resume_to_level(_get_resume_track_key(), Global.current_level)
	save_progress_button.icon = SAVE_ICON_IDLE
	save_progress_button.tooltip_text = "Guardar este avance en el dispositivo"
	save_feedback_backdrop.visible = false
	save_feedback_title.text = "Guardado local"
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR
	save_feedback_label.text = ""
	if save_feedback_timer == null:
		save_feedback_timer = Timer.new()
		save_feedback_timer.name = "SaveFeedbackResetTimer"
		save_feedback_timer.one_shot = true
		save_feedback_timer.wait_time = 3.0
		save_feedback_timer.timeout.connect(_on_save_feedback_timeout)
		add_child(save_feedback_timer)


func _exit_tree() -> void:
	if save_feedback_timer != null:
		save_feedback_timer.stop()
	if background != null:
		background.stop()
		background.stream = null

func _on_atrás_pressed():
	get_tree().change_scene_to_file("res://interface/libro.tscn")

func _victory():
	victory.show()
	victory.play("victory")
	adelante.disabled = false
	ensenanza.show()
	Global.items_level[Global.current_level][6] = true
	Global.clear_partial_level_state(_get_resume_track_key(), Global.current_level)
	SaveManager.record_level_completed(_get_resume_track_key(), Global.current_level)

func _on_adelante_pressed():
	if Global.current_level <= 5: 
		Global.current_level += 1
		get_tree().change_scene_to_file("res://niveles/nivel_1/Level.tscn")
	else:
		get_tree().change_scene_to_file("res://niveles/intro.tscn")


func _on_save_progress_button_pressed() -> void:
	var partial_save_result: Dictionary = manager_level.store_partial_level_state(_get_resume_track_key())
	SaveManager.record_manual_save()
	var save_status := SaveManager.get_save_status()
	var state := str(save_status.get("state", ""))
	if state == "error":
		_show_save_feedback("No se pudo guardar", _format_save_error_message(save_status), false)
	else:
		_show_save_feedback(_format_save_title(partial_save_result), _format_saved_message(save_status, partial_save_result), true)


func _get_resume_track_key() -> String:
	return TRACK_KEY


func _format_saved_message(save_status: Dictionary, partial_save_result: Dictionary) -> String:
	var last_saved_at := str(save_status.get("last_saved_at", ""))
	var saved_time := last_saved_at.get_slice(" ", 1)
	var lines: Array[String] = []
	if saved_time.is_empty():
		lines.append("Guardado en este dispositivo")
	else:
		lines.append("Guardado a las %s" % saved_time)
	var placed_positive_count := int(partial_save_result.get("placed_positive_count", 0))
	if placed_positive_count <= 0:
		lines.append("Capitulo %d listo para retomar" % Global.current_level)
	else:
		var noun := "alimento correcto" if placed_positive_count == 1 else "alimentos correctos"
		lines.append("%d %s en el plato" % [placed_positive_count, noun])
	return "\n".join(lines)


func _format_save_title(partial_save_result: Dictionary) -> String:
	if int(partial_save_result.get("placed_positive_count", 0)) > 0:
		return "Guardado parcial"
	return "Guardado local"


func _format_save_error_message(save_status: Dictionary) -> String:
	var last_error := str(save_status.get("last_error", "")).strip_edges()
	if not last_error.is_empty():
		return last_error
	return "Reintenta de nuevo en unos segundos"


func _show_save_feedback(title: String, message: String, success: bool) -> void:
	save_feedback_backdrop.visible = true
	save_feedback_title.text = title
	save_feedback_label.text = message
	save_feedback_title.modulate = SAVE_FEEDBACK_SUCCESS_TITLE_COLOR if success else SAVE_FEEDBACK_ERROR_TITLE_COLOR
	save_feedback_label.modulate = SAVE_FEEDBACK_SUCCESS_BODY_COLOR if success else SAVE_FEEDBACK_ERROR_BODY_COLOR
	save_progress_button.icon = SAVE_ICON_OK if success else SAVE_ICON_IDLE
	if save_feedback_timer != null:
		save_feedback_timer.stop()
		save_feedback_timer.start()


func _on_save_feedback_timeout() -> void:
	if not is_inside_tree():
		return
	save_progress_button.icon = SAVE_ICON_IDLE
	save_feedback_backdrop.visible = false
