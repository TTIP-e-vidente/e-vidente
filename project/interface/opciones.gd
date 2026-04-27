extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"


func _ready():
	MusicManager.reproducir_musica(MUSICA_FONDO)

func _on_atrás_pressed():
	GameSceneRouter.go_to_main_menu(get_tree())
