extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background_music: AudioStreamPlayer2D = $Background


func _ready() -> void:
	background_music.play()


func _on_start_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _on_opciones_pressed() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _on_salir_pressed() -> void:
	get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null
