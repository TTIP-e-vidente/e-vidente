extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var splash_animation: AnimatedSprite2D = $"e-vidente/AnimatedSprite2D"
@onready var background_music: AudioStreamPlayer2D = $Background


func _ready() -> void:
	_play_splash_animation()
	_play_background_music()


func _on_go_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _play_splash_animation() -> void:
	splash_animation.play(INTRO_ANIMATION)


func _play_background_music() -> void:
	background_music.play()
