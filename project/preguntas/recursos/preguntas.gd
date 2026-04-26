extends Resource
class_name Preguntas

@export var info_pregunta : String
@export var tipo : Enum.TipoPregunta
@export var pregunta_imagen : Texture2D
@export var pregunta_audio : AudioStream
@export var pregunta_video : VideoStream
@export var opciones: Array[String]
@export var correct : String
