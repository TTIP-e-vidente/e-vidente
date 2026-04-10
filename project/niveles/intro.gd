extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background: AudioStreamPlayer2D = $Background
@onready var play_backdrop: ColorRect = $PlayBackdrop
@onready var play_panel: PanelContainer = $PlayPanel
@onready var play_title: Label = $PlayPanel/MarginContainer/Content/Title
@onready var play_badge: Label = $PlayPanel/MarginContainer/Content/HeaderRow/StatusChip/MarginContainer/StatusBadge
@onready var play_subtitle: Label = $PlayPanel/MarginContainer/Content/Subtitle
@onready var resume_summary: Label = $PlayPanel/MarginContainer/Content/SummaryPanel/MarginContainer/ResumeSummary
@onready var continue_button: Button = $PlayPanel/MarginContainer/Content/ContinueButton
@onready var mode_button: Button = $PlayPanel/MarginContainer/Content/ModeButton

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const CONTINUE_BUTTON_TEXT := "Continuar ultima partida"
const MODE_BUTTON_TEXT := "Ir al selector de modos"
const START_BUTTON_TEXT := "Empezar desde el selector"


func _ready() -> void:
	background.play()
	_set_play_panel_visible(false)
	_refresh_play_panel()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://niveles/selector.tscn")


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/opciones.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	var resume_state := SaveManager.load_progress_and_get_resume_state(false)
	_set_play_panel_visible(false)
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_mode_pressed() -> void:
	_set_play_panel_visible(false)
	GameSceneRouter.go_to_archivero(get_tree())


func _on_play_close_pressed() -> void:
	_set_play_panel_visible(false)


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_play_panel_visible(false)


func _set_play_panel_visible(panel_visible: bool) -> void:
	play_backdrop.visible = panel_visible
	play_panel.visible = panel_visible


func _refresh_play_panel() -> void:
	var recent_save := _get_recent_save_summary()
	var can_resume := not recent_save.is_empty()

	continue_button.visible = can_resume
	continue_button.disabled = not can_resume
	continue_button.text = CONTINUE_BUTTON_TEXT

	if can_resume:
		play_badge.text = "ULTIMA PARTIDA"
		play_title.text = "Seguir jugando"
		play_subtitle.text = "Entrás directo al ultimo punto guardado, sin pasar por menus intermedios."
		resume_summary.text = _format_recent_save_summary(recent_save)
		mode_button.text = MODE_BUTTON_TEXT
		return

	play_badge.text = "PRIMERA PARTIDA"
	play_title.text = "Empezar a jugar"
	play_subtitle.text = "Todavia no hay una partida guardada en este equipo."
	resume_summary.text = "Entrá al selector para empezar. Cuando avances y guardes, este acceso te va a llevar directo donde lo dejaste."
	mode_button.text = START_BUTTON_TEXT


func _get_recent_save_summary() -> Dictionary:
	var slots := SaveManager.list_save_slots()
	if slots.is_empty():
		return {}
	return slots[0]


func _format_recent_save_summary(save_summary: Dictionary) -> String:
	var resume_hint := str(save_summary.get("resume_hint", "el selector de modos"))
	var updated_at := str(save_summary.get("updated_at", ""))
	var progress_summary: Dictionary = {}
	var raw_progress_summary: Variant = save_summary.get("progress_summary", {})
	var completed_levels := 0
	var total_levels := Global.LEVELS_PER_BOOK * Global.TRACK_KEYS.size()

	if raw_progress_summary is Dictionary:
		progress_summary = raw_progress_summary
		completed_levels = int(progress_summary.get("total", 0))
		total_levels = int(progress_summary.get("max_total", total_levels))

	var lines: Array[String] = ["Retomas en: %s" % resume_hint]
	if not updated_at.is_empty():
		lines.append("Guardado local: %s" % updated_at)
	lines.append("Avance general: %d/%d capitulos" % [completed_levels, total_levels])
	return "\n".join(lines)
