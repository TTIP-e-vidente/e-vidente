extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var jugar: Label = $MenuBar/Jugar/Label
@onready var opciones: Label = $MenuBar/Opciones/Label
@onready var salir: Label = $MenuBar/Salir/Label


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	opciones.text = "Cómo jugar?"

	salir.text = "Salir"


func _on_jugar_pressed() -> void:
	_abrir_modo_selector()


func _on_opciones_pressed() -> void:
	_abrir_opciones_menu()


func _on_salir_pressed() -> void:
	_salir_juego()


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO)

				
func _abrir_modo_selector() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_opciones_menu() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _salir_juego() -> void:
	get_tree().quit()
