extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background: AudioStreamPlayer2D = $Background
@onready var play_backdrop: ColorRect = $PlayBackdrop
@onready var play_panel: PanelContainer = $PlayPanel

const ARCHIVERO_SCENE := "res://interface/archivero.tscn"
const QUESTIONS_SCENE := "res://preguntas/pregunta.tscn"

func _ready() -> void:
	background.play()
	_set_resume_overlay_visible(false)


func _set_resume_overlay_visible(overlay_visible: bool) -> void:
	play_backdrop.visible = overlay_visible
	play_panel.visible = overlay_visible

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(ARCHIVERO_SCENE)


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file(QUESTIONS_SCENE)


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	if not SaveManager.can_resume_game():
		_set_resume_overlay_visible(false)
		return
	var resume_state := SaveManager.load_progress_and_get_resume_state(false)
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_resume_overlay_visible(false)


func _on_play_close_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_mode_pressed() -> void:
	_set_resume_overlay_visible(false)

func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_intro(get_tree())
