extends Node2D

@onready var container: Container = $CenterContainer/VBoxContainer/StatsContainer
@onready var container_2: Container = $CenterContainer/VBoxContainer/StatsContainer2
@onready var container_3: Container = $CenterContainer/VBoxContainer/StatsContainer3
@onready var textura : TextureRect = $CenterContainer/VBoxContainer/StatsContainer/Imagen
@onready var textura_2: TextureRect = $CenterContainer/VBoxContainer/StatsContainer2/Imagen
@onready var textura_3: TextureRect = $CenterContainer/VBoxContainer/StatsContainer3/Imagen
@onready var numero : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Numero
@onready var numero_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Numero
@onready var numero_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Numero
@onready var continuar: Label = $Continuar/Label

const PRESICION = preload("res://assets-sistema/final-leccion/presicion.png")
const PTOS_EXPERIENCIA = preload("res://assets-sistema/final-leccion/ptos-experiencia.png")
const TIEMPO = preload("res://assets-sistema/final-leccion/tiempo.png")
@onready var mensaje: Label = $Mensaje



func _ready() -> void:
	continuar.text = "Continuar"
	textura.texture = PTOS_EXPERIENCIA
	textura_2.texture = PRESICION
	textura_3.texture = TIEMPO
	
	mensaje.text = "Corregiste tres errores, no le digas a nadie!"
	numero.modulate = Color("#DBC151")
	numero_2.modulate = Color("#DB9D4B")
	numero_3.modulate = Color("#4B79DB")
	
	mostrar_resultados(
		22,
		83,
		"7:21"
	)


func mostrar_resultados(exp: int, precision: int, tiempo: String) -> void:
	numero.text = str(exp)
	numero_2.text = str(precision) + "%"
	numero_3.text = tiempo
