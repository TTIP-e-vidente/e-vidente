@tool
extends Control

var preguntas = []
var indice_actual = 0
var bloqueado = false

@onready var label_pregunta = $Pregunta
@onready var imagen = $Imagen
@onready var boton1 = $Boton1
@onready var boton2 = $Boton2
@onready var audio = $Audio

func _ready():
	if Engine.is_editor_hint():
		mostrar_preview()
	else:
		cargar_preguntas()
		conectar_botones()
		mostrar_pregunta()
		
func mostrar_preview():
	label_pregunta.text = "Ejemplo de pregunta para diseño"
	boton1.text = "Sí"
	boton2.text = "No"
	
	boton1.modulate = Color.WHITE
	boton2.modulate = Color.WHITE
	
	if imagen:
		imagen.visible = false

func cargar_preguntas():
	var file = FileAccess.open("res://preguntas/preguntas_recurso/preguntas.json", FileAccess.READ)
	preguntas = JSON.parse_string(file.get_as_text())


func mostrar_pregunta():
	bloqueado = false
	
	var p = preguntas[indice_actual]
	
	label_pregunta.text = p.pregunta
	

	if p.has("imagen") and p.imagen != "":
		imagen.texture = load(p.imagen)
		imagen.visible = true
	else:
		imagen.visible = false
	

	boton1.text = p.respuestas[0].texto
	boton2.text = p.respuestas[1].texto
	
	resetear_estilos()
	animar_entrada()
	

	if p.has("sonido") and p.sonido != "":
		audio.stream = load(p.sonido)
		audio.play()


func conectar_botones():
	boton1.pressed.connect(func(): verificar_respuesta(0, boton1))
	boton2.pressed.connect(func(): verificar_respuesta(1, boton2))
	
	boton1.mouse_entered.connect(func(): hover(boton1))
	boton2.mouse_entered.connect(func(): hover(boton2))
	
	boton1.mouse_exited.connect(func(): salir_hover(boton1))
	boton2.mouse_exited.connect(func(): salir_hover(boton2))


func verificar_respuesta(indice, boton):
	if bloqueado:
		return
	
	bloqueado = true
	
	var correcta = preguntas[indice_actual].respuestas[indice].correcta
	
	if correcta:
		respuesta_correcta(boton)
	else:
		respuesta_incorrecta(boton)
	
	await get_tree().create_timer(1.2).timeout
	cambiar_pregunta_suave()


func respuesta_correcta(boton):
	var tween = create_tween()
	tween.tween_property(boton, "modulate", Color(0.3, 1, 0.3), 0.2)
	tween.tween_property(boton, "scale", Vector2(1.1, 1.1), 0.2)

func respuesta_incorrecta(boton):
	var tween = create_tween()
	tween.tween_property(boton, "modulate", Color(1, 0.3, 0.3), 0.2)
	shake(boton)

func shake(boton):
	var original = boton.position
	
	var tween = create_tween()
	tween.tween_property(boton, "position:x", original.x + 10, 0.05)
	tween.tween_property(boton, "position:x", original.x - 10, 0.05)
	tween.tween_property(boton, "position:x", original.x, 0.05)


func hover(boton):
	var tween = create_tween()
	tween.tween_property(boton, "scale", Vector2(1.05, 1.05), 0.1)

func salir_hover(boton):
	var tween = create_tween()
	tween.tween_property(boton, "scale", Vector2(1, 1), 0.1)


func cambiar_pregunta_suave():
	var tween = create_tween()
	
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(func():
		indice_actual += 1
		
		if indice_actual >= preguntas.size():
			print("Juego terminado")
			return
		
		mostrar_pregunta()
	)
	
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func animar_entrada():
	self.modulate.a = 0
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func resetear_estilos():
	boton1.modulate = Color.WHITE
	boton2.modulate = Color.WHITE
	
	boton1.scale = Vector2(1, 1)
	boton2.scale = Vector2(1, 1)
