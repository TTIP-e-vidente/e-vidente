extends Node2D

const RUBIK_SPRAY := preload("res://fonts/RubikSprayPaint-Regular.ttf")

@onready var textura : TextureRect = $CenterContainer/VBoxContainer/StatsContainer/Imagen
@onready var textura_2: TextureRect = $CenterContainer/VBoxContainer/StatsContainer2/Imagen
@onready var textura_3: TextureRect = $CenterContainer/VBoxContainer/StatsContainer3/Imagen
@onready var numero : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Numero
@onready var numero_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Numero
@onready var numero_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Numero
@onready var continuar_label: Label = $Continuar/Label
@onready var continuar_btn: TextureButton = $Continuar
@onready var mensaje: Label = $Mensaje
@onready var audio_perfecto: AudioStreamPlayer2D = $AudioPerfecto
@onready var audio_normal: AudioStreamPlayer2D = $AudioNormal

const PTOS_EXPERIENCIA := preload("res://assets-sistema/final-leccion/ptos-experiencia.png")
const PRESICION := preload("res://assets-sistema/final-leccion/presicion.png")
const TIEMPO := preload("res://assets-sistema/final-leccion/tiempo.png")

const MAP_SCENE := "res://mapas/MapScene.tscn"



func _ready() -> void:
	# Iconos de los bloques de stats
	textura.texture = PTOS_EXPERIENCIA
	textura_2.texture = PRESICION
	textura_3.texture = TIEMPO

	# Colores de los valores (dorado, naranja, azul)
	numero.modulate = Color("#DBC151")
	numero_2.modulate = Color("#DB9D4B")
	numero_3.modulate = Color("#4B79DB")

	# Tipografía de los números
	for lbl in [numero, numero_2, numero_3]:
		lbl.add_theme_font_override("font", RUBIK_SPRAY)

	if continuar_label != null:
		continuar_label.text = "Continuar"

	# Leer los datos de resultado guardados en Global y mostrarlos
	var stats: Dictionary = Global.obtener_y_limpiar_ultima_finalizacion()
	if stats.is_empty():
		push_warning("[FinalizaciónPartida] Sin datos de finalización en Global.")
	mostrar_resultados(
		int(stats.get("exp_ganada", 0)),
		int(stats.get("precision", 100)),
		str(stats.get("tiempo", "0:00"))
	)

	# Conectar botón Continuar
	if continuar_btn != null and not continuar_btn.pressed.is_connected(continuar_al_mapa):
		continuar_btn.pressed.connect(continuar_al_mapa)


func mostrar_resultados(exp_ganada: int, precision: int, tiempo: String) -> void:
	numero.text = str(exp_ganada)
	numero_2.text = str(clamp(precision, 0, 100)) + "%"
	numero_3.text = tiempo if not tiempo.is_empty() else "--"

	if continuar_label != null:
		continuar_label.text = "Continuar"


	if precision >= 100:
		if not audio_perfecto.playing:
			audio_perfecto.play()
	else:
		if not audio_normal.playing:
			audio_normal.play()


## Vuelve al mapa con transición. También llamada por el test de humo.
func continuar_al_mapa() -> void:
	await TransicionEscenas.change_normal_scene(MAP_SCENE)


func _on_continuar_pressed() -> void:
	pass # Replace with function body.
