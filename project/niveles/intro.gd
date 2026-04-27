extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var buttons := [
	$MenuBar/Jugar,
	$MenuBar/Opciones,
	$MenuBar/Salir
]


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()

	
	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()

func _on_iniciar_presionado() -> void:
	_rebote_boton($MenuBar/Jugar)
	await get_tree().create_timer(0.15).timeout
	_abrir_modo_selector()


func _on_opciones_presionado() -> void:
	_rebote_boton($MenuBar/Opciones)
	await get_tree().create_timer(0.15).timeout
	_abrir_opciones_menu()


func _on_salir_presionado() -> void:
	_rebote_boton($MenuBar/Salir)
	await get_tree().create_timer(0.15).timeout
	_salir_juego()


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO)


func _exit_tree() -> void:
	pass


func _actualizar_sombreado_boton(button: Button, mat: ShaderMaterial):
	var mouse_global = get_viewport().get_mouse_position()
	var local_mouse = button.to_local(mouse_global)
	
	var uv_mouse = local_mouse / button.size
	
	if uv_mouse.x >= 0 and uv_mouse.x <= 1 and uv_mouse.y >= 0 and uv_mouse.y <= 1:
		mat.set_shader_parameter("mouse_pos", uv_mouse)
	else:
		mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))

func _process(_delta: float) -> void:
	var mouse = get_viewport().get_mouse_position()
	
	for b in buttons:
		var mat = b.material as ShaderMaterial
		if mat:
			var rect = b.get_global_rect()
			var uv = (mouse - rect.position) / rect.size
			
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			
			var center: Vector2 = rect.position + rect.size / 2.0
			var dist = mouse.distance_to(center)
			
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))
				
func _abrir_modo_selector() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_opciones_menu() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _salir_juego() -> void:
	get_tree().quit()

func _rebote_boton(button: Control):
	var tween = create_tween()
	
	var original_pos = button.position
	
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
