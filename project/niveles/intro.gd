extends Node2D
@onready var background = $Background

const AUTH_SCENE := "res://interface/auth.tscn"
const ARCHIVERO_SCENE := "res://interface/archivero.tscn"

func _ready():
	background.play()
	
func _on_start_pressed():
	if SaveManager.is_authenticated():
		get_tree().change_scene_to_file(ARCHIVERO_SCENE)
	else:
		get_tree().change_scene_to_file(AUTH_SCENE)

func _on_opciones_pressed():
	get_tree().change_scene_to_file("res://interface/opciones.tscn")

func _on_salir_pressed():
	get_tree().quit()



