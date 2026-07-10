extends Node2D
class_name EvidenteSplash

const INTRO_ANIMATION := "intro"
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"
const MobileUiLayoutHelperScript := preload("res://interface/helpers/MobileUiLayoutHelper.gd")

const LOGO_ESCALA_BASE := Vector2(0.867372, 0.858403)
const LOGO_POSICION_Y_BASE := 204.0

@onready var splash_animation: AnimatedSprite2D = $"e-vidente/AnimatedSprite2D"
@onready var go: Button = $go
@onready var _fondo_ficha: Control = $FondoFicha2


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	splash_animation.play(INTRO_ANIMATION)
	MusicManager.reproducir_musica(MUSICA_FONDO)
	get_viewport().size_changed.connect(_ajustar_layout_movil)
	call_deferred("_ajustar_layout_movil")
	await get_tree().create_timer(1.0).timeout
	animar_rebote_boton(go)
	await get_tree().create_timer(0.5).timeout
	animar_rebote_boton(go)


func _ajustar_layout_movil() -> void:
	var viewport := get_viewport_rect().size
	if is_instance_valid(_fondo_ficha):
		_fondo_ficha.position = Vector2.ZERO
		_fondo_ficha.scale = Vector2.ONE
		MobileUiLayoutHelperScript.aplicar_rect_completo(_fondo_ficha, viewport)
	_ajustar_logo(viewport)
	var ancho := clampf(viewport.x * 0.55, 220.0, 316.0)
	var alto := clampf(viewport.y * 0.28, 160.0, 283.0)
	go.scale = Vector2.ONE
	go.size = Vector2(ancho, alto)
	go.position = Vector2(
		(viewport.x - ancho) * 0.5,
		viewport.y - alto - maxf(48.0, viewport.y * 0.08)
	)
	MobileUiLayoutHelperScript.asegurar_minimo_tactil(go, 180.0)


func _ajustar_logo(viewport: Vector2) -> void:
	if not is_instance_valid(splash_animation):
		return
	var factor_ancho := clampf(viewport.x / MobileUiLayoutHelperScript.DISENO_ANCHO, 0.48, 1.0)
	splash_animation.scale = LOGO_ESCALA_BASE * factor_ancho
	splash_animation.position = Vector2(
		viewport.x * 0.5,
		LOGO_POSICION_Y_BASE * (viewport.y / MobileUiLayoutHelperScript.DISENO_ALTO)
	)
	
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
