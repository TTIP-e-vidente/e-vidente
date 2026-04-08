extends Node

@export var quiz: ThemePreg
@export var correcto: Color
@export var incorrecto : Color

var botones: Array[Button]
var index: int
var puntaje: int

@onready var preguntas: Label = $Contenido/Informacion/Pregunta
@onready var visual: Panel = $Contenido/Informacion/Visual
@onready var imagen: TextureRect = $Contenido/Informacion/Visual/Imagen
@onready var video: VideoStreamPlayer = $Contenido/Informacion/Visual/Video



func _ready() -> void:
	for boton in $Contenido/Preguntas.get_children():
		botones.append(boton)
		load_quiz()
		
func load_quiz() -> void:
	preguntas. text = quiz.theme[index].info_pregunta
	
	var opcion = quiz.theme[index].opciones
	for i in botones.size():
		botones[i].text = opcion[i]
	
	
	
	
