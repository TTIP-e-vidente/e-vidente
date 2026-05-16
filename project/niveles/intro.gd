extends Node2D
class_name MainMenu

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var jugar: Label = $MenuBar/Jugar/Label
@onready var opciones: Label = $MenuBar/Opciones/Label
@onready var salir: Label = $MenuBar/Salir/Label
@onready var _continuar_juego = $ContinuarJuego


func _ready() -> void:
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	jugar.text = "Jugar"
	opciones.text = "Como jugar?"
	salir.text = "Salir"
	_conectar_continuar_pendiente()
	_actualizar_continuar_pendiente()


func _on_jugar_pressed() -> void:
	_abrir_modo_selector()


func _on_opciones_pressed() -> void:
	_abrir_opciones_menu()


func _on_salir_pressed() -> void:
	_salir_juego()


func _conectar_continuar_pendiente() -> void:
	if _continuar_juego == null:
		return
	if _continuar_juego.has_signal("continuar_solicitado"):
		_continuar_juego.connect(
			"continuar_solicitado",
			Callable(self, "_on_continuar_pendiente_presionado")
		)


func _actualizar_continuar_pendiente() -> void:
	if _continuar_juego == null:
		return
	var global: Node = get_node_or_null("/root/Global")
	if (
		global != null
		and global.has_method("hay_juego_o_nodo_para_continuar")
		and bool(global.call("hay_juego_o_nodo_para_continuar"))
	):
		_continuar_juego.call("mostrar_para_continuar_pendiente")
	else:
		_continuar_juego.call("ocultar")


func _on_continuar_pendiente_presionado() -> void:
	GameSceneRouter.go_to_continue_target(get_tree(), GameSceneRouter.MODE_SELECTOR_SCENE_PATH)


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO)


func _abrir_modo_selector() -> void:
	GameSceneRouter.go_to_mode_selector(get_tree())


func _abrir_opciones_menu() -> void:
	GameSceneRouter.go_to_options(get_tree())


func _salir_juego() -> void:
	get_tree().quit()
