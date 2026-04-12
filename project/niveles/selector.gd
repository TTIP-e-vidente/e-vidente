extends Node2D
class_name ModeSelector

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const RESUME_FALLBACK_SCENE := "res://interface/archivero.tscn"

@onready var background_music: AudioStreamPlayer2D = $Background
@onready var resume_backdrop: ColorRect = $PlayBackdrop
@onready var resume_panel: PanelContainer = $PlayPanel

func _ready() -> void:
	_play_background_music()
	_set_resume_overlay_visible(false)


func _set_resume_overlay_visible(overlay_visible: bool) -> void:
	resume_backdrop.visible = overlay_visible
	resume_panel.visible = overlay_visible

func _on_start_pressed() -> void:
	_open_recipe_hub()


func _on_opciones_pressed() -> void:
	_open_questions_mode()


func _on_salir_pressed() -> void:
	_quit_game()


func _on_continue_pressed() -> void:
	_resume_last_saved_flow()


func _on_play_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_resume_overlay_visible(false)


func _on_play_close_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_mode_pressed() -> void:
	_set_resume_overlay_visible(false)


func _on_atras_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _play_background_music() -> void:
	background_music.play()


func _open_recipe_hub() -> void:
	GameSceneRouter.go_to_archivero(get_tree())


func _open_questions_mode() -> void:
	GameSceneRouter.go_to_questions(get_tree())


func _quit_game() -> void:
	get_tree().quit()


func _resume_last_saved_flow() -> void:
	if not SaveManager.can_resume_current_save():
		_set_resume_overlay_visible(false)
		return
	var resume_state := SaveManager.load_current_save_and_get_resume_state(false)
	GameSceneRouter.go_to_resume(get_tree(), resume_state, RESUME_FALLBACK_SCENE)
