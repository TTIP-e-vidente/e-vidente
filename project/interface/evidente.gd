extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var splash_animation: AnimatedSprite2D = $"e-vidente/AnimatedSprite2D"
@onready var background_music: AudioStreamPlayer2D = $Background
@onready var go: Button = $go


func _ready() -> void:
	splash_animation.play(INTRO_ANIMATION)
	background_music.play()
	await get_tree().create_timer(1.0).timeout
	bounce_button(go)
	await get_tree().create_timer(0.5).timeout
	bounce_button(go)
	
func bounce_button(button: Control):
	var tween = create_tween()
	var original_pos = button.position
	
	tween.tween_property(go, "position:y", original_pos.y - 6, 0.06)
	tween.tween_property(go, "position:y", original_pos.y + 2, 0.05)
	tween.tween_property(go, "position:y", original_pos.y, 0.06)

func _on_go_pressed() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null
