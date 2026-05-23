extends TextureButton

@onready var jugar: TextureButton = $"."
@onready var label: Label = $Label
@onready var imagen_restriccion: Sprite2D = $"imagen-restriccion"

var tween_rebote: Tween


func ajustar_fuente(label: Label, texto: String) -> void:
	label.text = texto

	var largo := texto.length()
	var font_size := 32

	if largo > 40:
		font_size = 20
	elif largo > 32:
		font_size = 24
	elif largo > 24:
		font_size = 28

	label.remove_theme_font_size_override("font_size")
	label.add_theme_font_size_override("font_size", font_size)	


func _ready() -> void:
	if jugar.material:
		jugar.material = jugar.material.duplicate()

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	ajustar_fuente(label, label.text)


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
	if tween_rebote:
		tween_rebote.kill()

	var original_pos = button.position
	var original_scale = button.scale

	button.scale = original_scale
	button.position = original_pos

	tween_rebote = create_tween()

	var pressed_scale = original_scale * 0.97

	tween_rebote.parallel().tween_property(
		button,
		"scale",
		pressed_scale,
		0.10
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween_rebote.parallel().tween_property(
		button,
		"position",
		original_pos + Vector2(0, 8),
		0.10
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween_rebote.parallel().tween_property(
		button,
		"scale",
		original_scale,
		0.22
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	tween_rebote.parallel().tween_property(
		button,
		"position",
		original_pos,
		0.22
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func establecer_imagen(ruta: String) -> void:
	var textura: Texture2D = load(ruta)
	imagen_restriccion.texture = textura
	
	
func _on_pressed() -> void:

	modulate = Color("#42785e")
	
	_rebote_boton(jugar)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE
