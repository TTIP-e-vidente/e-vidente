extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const SELECTOR_SCENE := "res://niveles/selector.tscn"

@onready var background: AudioStreamPlayer2D = $Background


func _ready() -> void:
	background.play()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(SELECTOR_SCENE)


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://interface/opciones.tscn")


func _on_salir_pressed() -> void:
	get_tree().quit()
