extends Node2D
class_name MainMenu

const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var jugarb: TextureButton = $MenuBar/Jugar
@onready var opcionesb: TextureButton = $MenuBar/Opciones
@onready var salirb: TextureButton = $MenuBar/Salir

@onready var jugar: Label = $MenuBar/Jugar/Label
@onready var opciones: Label = $MenuBar/Opciones/Label
@onready var salir: Label = $MenuBar/Salir/Label

@onready var jugari: Sprite2D = $MenuBar/Jugar/imagen
@onready var opcionesi:Sprite2D = $MenuBar/Opciones/imagen
@onready var saliri: Sprite2D = $MenuBar/Salir/imagen

const COMO_JUGAR := preload ("res://assets-sistema/intro/como-jugar-intro-1.png")
const JUGAR := preload("res://assets-sistema/intro/play-intro-1.png")
const SALIR :=preload("res://assets-sistema/intro/salir-intro-1.png")



@onready var buttons: Array[TextureButton] = [
	$MenuBar/Jugar,
	$MenuBar/Opciones,
	$MenuBar/Salir,
]


func _ready() -> void:
	jugarb.modulate = Color("#42785e")
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	jugar.text = "Jugar"
	opciones.text = "Cómo jugar?"
	salir.text = "Salir"
	jugari.texture = JUGAR
	opcionesi.texture = COMO_JUGAR
	saliri.texture = SALIR


func _on_jugar_pressed() -> void:
	GameSceneRouter.transition_to_scene(_abrir_modo_selector())


func _on_opciones_pressed() -> void:
	GameSceneRouter.transition_to_scene(_abrir_opciones_menu())


func _on_salir_pressed() -> void:
	get_tree().quit()


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO)


func _abrir_modo_selector() -> String:
	return GameSceneRouter.MODE_SELECTOR_SCENE_PATH


func _abrir_opciones_menu() -> String:
	return GameSceneRouter.OPTIONS_SCENE_PATH
