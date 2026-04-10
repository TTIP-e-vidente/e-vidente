extends Node2D

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background = $Background

func _ready():
	background.play()

func _on_atrás_pressed():
	GameSceneRouter.go_to_intro(get_tree())
