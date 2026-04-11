extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

@onready var background: AudioStreamPlayer2D = $Background


func _ready() -> void:
	background.play()


func _on_start_pressed() -> void:
	if not SaveManager.can_resume_game():
		GameSceneRouter.go_to_archivero(get_tree())
		return
	var resume_state: Dictionary = SaveManager.load_progress_and_get_resume_state(false)
	GameSceneRouter.go_to_resume(get_tree(), resume_state, ARCHIVERO_SCENE)


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/opciones.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()
