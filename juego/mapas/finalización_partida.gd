extends Node2D

const RUBIK_SPRAY := preload("res://fonts/RubikSprayPaint-Regular.ttf")
const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")

@onready var textura : TextureRect = $CenterContainer/VBoxContainer/StatsContainer/Imagen
@onready var textura_2: TextureRect = $CenterContainer/VBoxContainer/StatsContainer2/Imagen
@onready var textura_3: TextureRect = $CenterContainer/VBoxContainer/StatsContainer3/Imagen
@onready var label : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Label
@onready var label_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Label
@onready var label_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Label
@onready var numero : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Numero
@onready var numero_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Numero
@onready var numero_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Numero
@onready var continuar_label: Label = $Continuar/Label
@onready var continuar_btn: TextureButton = $Continuar
@onready var mensaje: Label = $Mensaje
@onready var audio_perfecto: AudioStreamPlayer2D = $AudioPerfecto
@onready var audio_normal: AudioStreamPlayer2D = $AudioNormal
@onready var label_sync_status: Label = $LabelSyncStatus

@onready var stats_1: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer
@onready var stats_2: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer2
@onready var stats_3: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer3
const EXP_ICON = preload("res://assets-sistema/final-leccion/exp-icon.png")
const PRECISION_ICON = preload("res://assets-sistema/final-leccion/precision-icon.png")
const TIEMPO_ICON = preload("res://assets-sistema/final-leccion/tiempo-icon.png")


const MAP_SCENE := "res://mapas/MapScene.tscn"

const CUADRADO_2X_2 = preload("res://assets-sistema/interfaz/cuadrado-2x2.png")

var _sync_tween: Tween = null


func _formatear_tiempo(segundos_totales: float) -> String:
	var s := int(segundos_totales)
	if s < 60:
		return "%ds" % s
	var m: int = floori(float(s) / 60.0)
	var rem_s := s % 60
	if rem_s == 0:
		return "%dm" % m
	return "%dm %ds" % [m, rem_s]

func _ready() -> void:
	# Iconos de los bloques de stats
	label.text = "EXP"
	label_2.text = "Precisión"
	label_3.text = "Tiempo"
	stats_1.setear_icono(EXP_ICON)
	stats_2.setear_icono(PRECISION_ICON)
	stats_3.setear_icono(TIEMPO_ICON)
	
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
	
	var elapsed_seconds := float(stats.get("elapsed_seconds", -1.0))
	var tiempo_final = "-"
	if elapsed_seconds >= 0.0:
		tiempo_final = _formatear_tiempo(elapsed_seconds)
		print("[FinalizacionPartida] displaying_time=", tiempo_final)
	elif stats.has("tiempo") and str(stats.get("tiempo", "")) != "—" and str(stats.get("tiempo", "")) != "":
		tiempo_final = str(stats.get("tiempo", ""))
		print("[FinalizacionPartida] displaying_time=", tiempo_final)

	mostrar_resultados(
		int(stats.get("exp_ganada", stats.get("exp", 0))),
		_leer_precision_real(stats),
		tiempo_final
	)

	# Inicializar feedback de sync
	if label_sync_status != null:
		label_sync_status.text = SyncApi.mensaje_guardado_local()
		if SyncApi.puede_sincronizar():
			label_sync_status.text = SyncApi.mensaje_sincronizando()
			SyncApi.conectar_feedback_sincronizacion(
				_al_sync_exitosa, _al_sync_fallida, _al_sync_pendientes_terminado
			)
			_iniciar_animacion_sync()
			call_deferred("_evaluar_estado_sync_inicial")

	# Conectar botón Continuar
	if continuar_btn != null and not continuar_btn.pressed.is_connected(continuar_al_mapa):
		continuar_btn.pressed.connect(continuar_al_mapa)


func _exit_tree() -> void:
	_limpiar_feedback_sync()


# Completado no implica 100% de precisión.
func _leer_precision_real(stats: Dictionary) -> int:
	var intentos := int(stats.get("intentos", 0))
	if intentos > 0:
		return NodoProgressionRulesScript.calcular_precision(
			int(stats.get("aciertos", 0)),
			intentos
		)
	if stats.has("precision"):
		return int(stats.get("precision", 0))
	# Compatibilidad: algunos resultados legacy guardan accuracy como ratio 0.0–1.0.
	if stats.has("accuracy"):
		var accuracy := float(stats.get("accuracy", 0.0))
		if accuracy <= 1.0:
			return int(round(accuracy * 100.0))
		return int(round(accuracy))
	return 0


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


func continuar_al_mapa() -> void:
	await TransicionEscenas.cambiar_escena_normal(MAP_SCENE)


func _on_continuar_presionado() -> void:
	pass # Replace with function body.


func _al_sync_exitosa(_progress: Dictionary) -> void:
	if label_sync_status != null:
		_detener_tween_sync()
		label_sync_status.text = SyncApi.mensaje_sync_exitosa()
		label_sync_status.modulate.a = 1.0


func _al_sync_fallida(_motivo: String) -> void:
	if label_sync_status != null:
		_detener_tween_sync()
		label_sync_status.text = SyncApi.mensaje_sync_pendiente()
		label_sync_status.modulate.a = 1.0


func _al_sync_pendientes_terminado(synced_count: int, failed_count: int) -> void:
	if label_sync_status == null:
		return
	_detener_tween_sync()
	label_sync_status.text = SyncApi.mensaje_resultado_batch(synced_count, failed_count)
	label_sync_status.modulate.a = 1.0


func _evaluar_estado_sync_inicial() -> void:
	SyncApi.evaluar_sync_inicial_tras_encolado(_al_sync_pendientes_terminado)


func _iniciar_animacion_sync() -> void:
	_detener_tween_sync()
	_sync_tween = create_tween().set_loops()
	_sync_tween.tween_property(label_sync_status, "modulate:a", 0.4, 0.6)
	_sync_tween.tween_property(label_sync_status, "modulate:a", 1.0, 0.6)


func _detener_tween_sync() -> void:
	if _sync_tween != null and is_instance_valid(_sync_tween):
		_sync_tween.kill()
	_sync_tween = null


func _limpiar_feedback_sync() -> void:
	_detener_tween_sync()
	SyncApi.desconectar_feedback_sincronizacion(
		_al_sync_exitosa, _al_sync_fallida, _al_sync_pendientes_terminado
	)
