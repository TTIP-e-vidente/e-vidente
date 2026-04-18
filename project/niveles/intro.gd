extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@onready var background_music: AudioStreamPlayer2D = $Background

@onready var buttons := [
	$MenuBar/Jugar,
	$MenuBar/Opciones,
	$MenuBar/Salir
]


func _ready() -> void:
	_play_background_music()

	
	for b in buttons:
		if b.material:
			b.material = b.material.duplicate()

func _on_start_pressed() -> void:
	_bounce_button($MenuBar/Jugar)
	await get_tree().create_timer(0.15).timeout
	_open_mode_selector()


func _on_opciones_pressed() -> void:
	_bounce_button($MenuBar/Opciones)
	await get_tree().create_timer(0.15).timeout
	_open_options_menu()


func _on_salir_pressed() -> void:
	_bounce_button($MenuBar/Salir)
	await get_tree().create_timer(0.15).timeout
	_quit_game()


func _play_background_music() -> void:
	background_music.play()


func _exit_tree() -> void:
	if is_instance_valid(background_music):
		background_music.stop()
		background_music.stream = null


func _update_button_shader(button: Button, mat: ShaderMaterial):
	var mouse_global = get_viewport().get_mouse_position()
	var local_mouse = button.to_local(mouse_global)
	
	var uv_mouse = local_mouse / button.size
	
	if uv_mouse.x >= 0 and uv_mouse.x <= 1 and uv_mouse.y >= 0 and uv_mouse.y <= 1:
		mat.set_shader_parameter("mouse_pos", uv_mouse)
	else:
		mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))

func _process(delta):
	var mouse = get_viewport().get_mouse_position()
	
	for b in buttons:
		var mat = b.material as ShaderMaterial
		if mat:
			var rect = b.get_global_rect()
			var uv = (mouse - rect.position) / rect.size
			
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			
			var center = rect.position + rect.size / 2
			var dist = mouse.distance_to(center)
			
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))
				
func _open_mode_selector() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _open_options_menu() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _quit_game() -> void:
	get_tree().quit()

func _bounce_button(button: Control):
	var tween = create_tween()
	
	var original_pos = button.position
	
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
