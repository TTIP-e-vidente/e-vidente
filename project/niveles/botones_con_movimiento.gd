extends TextureButton

@onready var jugar: TextureButton = $"."
@onready var label: Label = $Label

func ajustar_fuente(label: Label, texto: String) -> void:
	label.text = texto

	var largo := texto.length()

	if largo > 20:
		label.add_theme_font_size_override("font_size", 20)
	elif largo > 12:
		label.add_theme_font_size_override("font_size", 26)
	else:
		label.add_theme_font_size_override("font_size", 34)


func _ready() -> void:
	if jugar.material:
		jugar.material = jugar.material.duplicate()
	ajustar_fuente(label,label.text)

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
	var mat = jugar.material as ShaderMaterial
	if mat:
			var rect = jugar.get_global_rect()
			var uv = (mouse - rect.position) / rect.size
			
			uv.x = clamp(uv.x, 0.0, 1.0)
			uv.y = clamp(uv.y, 0.0, 1.0)
			
			var center: Vector2 = rect.position + rect.size / 2.0
			var dist = mouse.distance_to(center)
			
			if dist < 200:
				mat.set_shader_parameter("mouse_pos", uv)
			else:
				mat.set_shader_parameter("mouse_pos", Vector2(0.5, 0.5))
				

func _rebote_boton(button: Control):
	var tween = create_tween()
	
	var original_pos = button.position
	
	tween.tween_property(button, "position", original_pos + Vector2(0, 4), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(button, "position", original_pos, 0.08)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	_rebote_boton($".")
	await get_tree().create_timer(0.15).timeout
