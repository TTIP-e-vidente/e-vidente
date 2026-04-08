extends Node2D
class_name Intro

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var anim = $"e-vidente/AnimatedSprite2D"
@onready var background = $Background

func _ready():
	anim.play("intro")
	background.play()

func _on_go_pressed():
	GameSceneRouter.go_to_intro(get_tree())
