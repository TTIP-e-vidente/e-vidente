extends Node

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@export var quiz: ThemePreg

var botones: Array
var index: int
var puntaje: int
var bloqueado := false

var pregunta_actual: Preguntas:
	get : return quiz.theme[index]

@onready var preguntas: Label = $Contenido/Informacion/Pregunta

func _ready() -> void:
	puntaje = 0
	
	for boton in $Contenido/Preguntas.get_children():
		botones.append(boton)
		boton.pressed.connect(_respuesta_boton.bind(boton))
	
	_randomizar_preguntas(quiz.theme)
	load_quiz()

func load_quiz() -> void:
	bloqueado = false
	
	if index >= quiz.theme.size():
		_game_over()
		return
	
	preguntas.text = pregunta_actual.info_pregunta
	
	var opcion = pregunta_actual.opciones
	
	for i in botones.size():
		var boton = botones[i]
		
		boton.text = opcion[i]
		boton.set_meta("respuesta", opcion[i])
		
		boton.modulate = Color.WHITE
		boton.disabled = false
		boton.scale = Vector2.ONE
		boton.rotation_degrees = 0

func _respuesta_boton(boton) -> void:
	if bloqueado:
		return
	
	bloqueado = true
	
	for b in botones:
		b.disabled = true
	
	var texto = boton.get_meta("respuesta")
	
	if pregunta_actual.correct == texto:
		_respuesta_correcta(boton)
		puntaje += 1
	else:
		_respuesta_incorrecta(boton)
	
	await get_tree().create_timer(1.2).timeout
	_siguiente_pregunta()

func _respuesta_correcta(boton):
	var tween = create_tween()
	
	boton.modulate = Color(0, 1, 0)
	
	tween.tween_property(boton, "scale", Vector2(1.2, 0.8), 0.08)
	tween.tween_property(boton, "scale", Vector2(0.9, 1.1), 0.08)
	tween.tween_property(boton, "scale", Vector2(1.05, 0.95), 0.08)
	tween.tween_property(boton, "scale", Vector2(1, 1), 0.1)

func _respuesta_incorrecta(boton):
	var tween = create_tween()
	
	boton.modulate = Color(1, 0, 0)
	
	for i in 5:
		tween.tween_property(boton, "rotation_degrees", 8, 0.03)
		tween.tween_property(boton, "rotation_degrees", -8, 0.03)
	
	tween.tween_property(boton, "rotation_degrees", 0, 0.05)

func _siguiente_pregunta() -> void:
	index += 1
	load_quiz()

func _randomizar_preguntas(array :Array) -> Array:
	array.shuffle()
	return array

func _game_over() -> void:
	$Contenido/GameOver.show()
	$Contenido/GameOver/Puntaje.text = str(puntaje, "/", quiz.theme.size())

func _on_jugar_nuevamente_pressed() -> void:
	get_tree().reload_current_scene()

func _on_atrás_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
