extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var splash_animation: AnimatedSprite2D = $"e-vidente/AnimatedSprite2D"
@onready var go: Button = $go


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	splash_animation.play(INTRO_ANIMATION)
	MusicManager.reproducir_musica(MUSICA_FONDO)
	await get_tree().create_timer(1.0).timeout
	animar_rebote_boton(go)
	await get_tree().create_timer(0.5).timeout
	animar_rebote_boton(go)
	
func animar_rebote_boton(button: Control):
	var tween = create_tween()
	var original_pos = button.position
	
	tween.tween_property(button, "position:y", original_pos.y - 6, 0.06)
	tween.tween_property(button, "position:y", original_pos.y + 2, 0.05)
	tween.tween_property(button, "position:y", original_pos.y, 0.06)

func _on_ir_presionado() -> void:
	GameSceneRouter.go_to_main_menu(get_tree())


func _exit_tree() -> void:
	pass
