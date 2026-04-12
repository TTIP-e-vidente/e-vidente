extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background_music: AudioStreamPlayer2D = $Background


func _ready() -> void:
	_play_background_music()


func _on_start_pressed() -> void:
	_open_mode_selector()


func _on_opciones_pressed() -> void:
	_open_options_menu()


func _on_salir_pressed() -> void:
	_quit_game()


func _play_background_music() -> void:
	background_music.play()


func _open_mode_selector() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _open_options_menu() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _quit_game() -> void:
	get_tree().quit()
