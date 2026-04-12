extends Node

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

@export var quiz: ThemePreg
@export var correcto: Color
@export var incorrecto : Color

var botones: Array[Button]
var index: int
var puntaje: int

var pregunta_actual: Preguntas:
	get : return quiz.theme[index]

@onready var preguntas: Label = $Contenido/Informacion/Pregunta
@onready var visual: Panel = $Contenido/Informacion/Visual
@onready var imagen: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var video: VideoStreamPlayer = $Contenido/Informacion/Visual/Video


func _ready() -> void:
	puntaje = 0
	for boton in $Contenido/Preguntas.get_children():
		botones.append(boton)
	
	_randomizar_preguntas(quiz.theme)
	load_quiz()
		
func load_quiz() -> void:
	if index >= quiz.theme.size():
		_game_over()
		return
	
	preguntas.text = pregunta_actual.info_pregunta
	
	var opcion = pregunta_actual.opciones
	for i in botones.size():
		botones[i].text = opcion[i]
		botones[i].pressed.connect(_respuesta_boton.bind(botones[i]))
		
func _respuesta_boton(boton) -> void:
	if pregunta_actual.correct == boton.text:
		boton.modulate = Color(0, 1, 0)
		puntaje +=1
	else:
		boton.modulate = Color(1, 0, 0)
	
	_siguiente_pregunta()
	
func _siguiente_pregunta() -> void:
	for bt in botones:
		bt.pressed.disconnect(_respuesta_boton)
		
	await get_tree().create_timer(1).timeout
	
	for bt in botones:
		bt.modulate = Color.WHITE
	
	
	index += 1
	load_quiz()

func _randomizar_preguntas(array :Array) -> Array:
	var array_temp := array
	array.shuffle()
	return array
	

func _game_over() -> void:
	$Contenido/GameOver.show()
	$Contenido/GameOver/Puntaje.text = str(puntaje, "/", quiz.theme.size())



func _on_jugar_nuevamente_pressed() -> void:
	get_tree().reload_current_scene()


func _on_atrás_pressed() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())
