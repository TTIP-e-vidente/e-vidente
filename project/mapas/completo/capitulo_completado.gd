extends Node2D
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

func _ready():
	get_tree().paused = true

func _on_button_pressed():
	get_tree().paused = false
	queue_free()


func _on_continuar_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())
