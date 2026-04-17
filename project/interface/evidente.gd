extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var splash_animation: AnimatedSprite2D = $"e-vidente/AnimatedSprite2D"
@onready var background_music: AudioStreamPlayer2D = $Background


func _ready() -> void:
	splash_animation.play(INTRO_ANIMATION)
	background_music.play()


func _on_go_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null
