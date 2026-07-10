extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
const MobileUiLayoutHelperScript := preload("res://interface/helpers/MobileUiLayoutHelper.gd")

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
	get_viewport().size_changed.connect(_ajustar_layout_movil)
	call_deferred("_ajustar_layout_movil")


func _ajustar_layout_movil() -> void:
	var viewport := get_viewport_rect().size
	var ancho := clampf(viewport.x * 0.55, 220.0, 316.0)
	var alto := clampf(viewport.y * 0.28, 160.0, 283.0)
	go.scale = Vector2.ONE
	go.size = Vector2(ancho, alto)
	go.position = Vector2(
		(viewport.x - ancho) * 0.5,
		viewport.y - alto - maxf(48.0, viewport.y * 0.08)
	)
	MobileUiLayoutHelperScript.asegurar_minimo_tactil(go, 180.0)
	
func animar_rebote_boton(button: Control):
	var tween = create_tween()
	var original_pos = button.position
	
	tween.tween_property(button, "position:y", original_pos.y - 6, 0.06)
	tween.tween_property(button, "position:y", original_pos.y + 2, 0.05)
	tween.tween_property(button, "position:y", original_pos.y, 0.06)

func _on_ir_presionado() -> void:
	GameSceneRouter.transicionar_a_escena(_escena_princ())
	

func _escena_princ() -> String:
	return GameSceneRouter.MAIN_MENU_SCENE_PATH


func _exit_tree() -> void:
	pass
