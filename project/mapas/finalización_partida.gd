extends Node2D

## Pantalla oficial de resultados al completar una leccion/nodo.
##
## Lee los datos de Global.obtener_y_limpiar_ultima_finalizacion() en _ready()
## y actualiza los tres StatsContainer del diseno existente.
## El boton Continuar regresa al mapa.

@onready var textura : TextureRect = $CenterContainer/VBoxContainer/StatsContainer/Imagen
@onready var textura_2: TextureRect = $CenterContainer/VBoxContainer/StatsContainer2/Imagen
@onready var textura_3: TextureRect = $CenterContainer/VBoxContainer/StatsContainer3/Imagen
@onready var numero : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Numero
@onready var numero_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Numero
@onready var numero_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Numero
@onready var continuar_label: Label = $Continuar/Label
@onready var continuar_btn: TextureButton = $Continuar
@onready var mensaje: Label = $Mensaje

const PTOS_EXPERIENCIA := preload("res://assets-sistema/final-leccion/ptos-experiencia.png")
const PRESICION := preload("res://assets-sistema/final-leccion/presicion.png")
const TIEMPO := preload("res://assets-sistema/final-leccion/tiempo.png")

const MAP_SCENE := "res://mapas/MapScene.tscn"


func _ready() -> void:
	# Asignar iconos a los tres bloques de stats
	textura.texture = PTOS_EXPERIENCIA
	textura_2.texture = PRESICION
	textura_3.texture = TIEMPO

	# Colores de los valores (dorado, naranja, azul)
	numero.modulate = Color("#DBC151")
	numero_2.modulate = Color("#DB9D4B")
	numero_3.modulate = Color("#4B79DB")

	# Texto del boton continuar
	if continuar_label != null:
		continuar_label.text = "Continuar"

	# Leer datos reales del Global y mostrar
	var stats: Dictionary = Global.obtener_y_limpiar_ultima_finalizacion()
	var exp_ganada: int = int(stats.get("exp_ganada", 0))
	var precision: int = int(stats.get("precision", 100))
	var tiempo: String = str(stats.get("tiempo", "--")).strip_edges()

	mostrar_resultados(exp_ganada, precision, tiempo)

	# Conectar boton Continuar (script = null en la instancia, conectamos aqui)
	if continuar_btn != null and not continuar_btn.pressed.is_connected(_al_continuar):
		continuar_btn.pressed.connect(_al_continuar)


## Actualiza los tres bloques de stats con los valores reales de la partida.
func mostrar_resultados(exp_ganada: int, precision: int, tiempo: String) -> void:
	numero.text = str(exp_ganada)
	numero_2.text = str(clamp(precision, 0, 100)) + "%"
	numero_3.text = tiempo if not tiempo.is_empty() else "--"


## Alias publico para que otros sistemas puedan forzar el retorno al mapa.
func continuar_al_mapa() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


func _al_continuar() -> void:
	continuar_al_mapa()