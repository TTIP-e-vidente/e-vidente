extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RESUME_FALLBACK_SCENE := "res://interface/archivero.tscn"

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

func _ready() -> void:
	background_music.play()
	_set_resume_overlay_visible(false)


func _set_resume_overlay_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible

func _on_start_pressed() -> void:
	GameSceneRouter.go_to_archivero(get_tree())


func _on_opciones_pressed() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _on_salir_pressed() -> void:
	get_tree().quit()


func _on_continue_pressed() -> void:
	if not SaveManager.can_resume_current_save():
		_set_resume_overlay_visible(false)
		return
	var resume_state := SaveManager.reload_current_save_and_get_resume_state()
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_resume_overlay_visible(false)


func _on_play_close_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_mode_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null
