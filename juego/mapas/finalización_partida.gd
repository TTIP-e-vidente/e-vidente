extends Node2D

const RUBIK_SPRAY := preload("res://fonts/RubikSprayPaint-Regular.ttf")
const NodoProgressionRulesScript := preload("res://sistemas/NodoProgressionRules.gd")

@onready var label : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Label
@onready var label_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Label
@onready var label_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Label
@onready var numero : Label = $CenterContainer/VBoxContainer/StatsContainer/Imagen/Numero
@onready var numero_2: Label = $CenterContainer/VBoxContainer/StatsContainer2/Imagen/Numero
@onready var numero_3: Label = $CenterContainer/VBoxContainer/StatsContainer3/Imagen/Numero
@onready var continuar_label: Label = $Continuar/Label
@onready var audio_perfecto: AudioStreamPlayer2D = $AudioPerfecto
@onready var audio_normal: AudioStreamPlayer2D = $AudioNormal
@onready var label_sync_status: Label = $UiAnchor/LabelSyncStatus
@onready var mensaje: Label = $Mensaje

@onready var stats_1: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer
@onready var stats_2: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer2
@onready var stats_3: ContenedorEstadisticas = $CenterContainer/VBoxContainer/StatsContainer3
const EXP_ICON = preload("res://assets-sistema/final-leccion/exp-icon.png")
const PRECISION_ICON = preload("res://assets-sistema/final-leccion/precision-icon.png")
const TIEMPO_ICON = preload("res://assets-sistema/final-leccion/tiempo-icon.png")
@export var animated_sprite_2d: AnimatedSprite2D

const MOSTRAR_COMPARACION_PRECISION_UI := false

var _sync_tween: Tween = null
var _comparacion_precision: Dictionary = {}


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
	label.text = "EXP"
	label_2.text = "Precisión"
	label_3.text = "Tiempo"
	stats_1.setear_icono(EXP_ICON)
	stats_2.setear_icono(PRECISION_ICON)
	stats_3.setear_icono(TIEMPO_ICON)
	animated_sprite_2d.play("recontento")
	numero.modulate = Color("#DBC151")
	numero_2.modulate = Color("#DB9D4B")
	numero_3.modulate = Color("#4B79DB")

	for lbl in [numero, numero_2, numero_3]:
		lbl.add_theme_font_override("font", RUBIK_SPRAY)

	var stats: Dictionary = Global.obtener_ultima_finalizacion()
	if stats.is_empty():
		push_warning("[FinalizaciónPartida] Sin datos de finalización en Global.")

	var precision_actual := 0
	if not stats.is_empty():
		precision_actual = _leer_precision_real(stats)

	var elapsed_seconds := float(stats.get("elapsed_seconds", -1.0))
	var tiempo_final = "-"
	if elapsed_seconds >= 0.0:
		tiempo_final = _formatear_tiempo(elapsed_seconds)
	elif stats.has("tiempo") and str(stats.get("tiempo", "")) != "—" and str(stats.get("tiempo", "")) != "":
		tiempo_final = str(stats.get("tiempo", ""))

	mostrar_resultados(
		int(stats.get("exp_ganada", stats.get("exp", 0))),
		precision_actual,
		tiempo_final
	)
	_actualizar_titulo_leccion(precision_actual)
	_mostrar_comparacion_precision(stats, precision_actual)
	_ocultar_ui_de_ranking()
	_configurar_boton_continuar()
	_aplicar_estilo_sync()

	if label_sync_status != null:
		label_sync_status.text = SyncApi.mensaje_guardado_local()
		if SyncApi.puede_sincronizar():
			label_sync_status.text = SyncApi.mensaje_sincronizando()
			SyncApi.conectar_feedback_sincronizacion(
				_al_sync_exitosa, _al_sync_fallida, _al_sync_pendientes_terminado
			)
			_iniciar_animacion_sync()
			call_deferred("_evaluar_estado_sync_inicial")

	call_deferred("_prefetch_ranking_en_segundo_plano")


func _exit_tree() -> void:
	_limpiar_feedback_sync()


func _ocultar_ui_de_ranking() -> void:
	if mensaje != null and not MOSTRAR_COMPARACION_PRECISION_UI:
		mensaje.visible = false
	var saltar := get_node_or_null("UiAnchor/SaltarAlMapa")
	if saltar != null:
		saltar.visible = false
	var checkbox := get_node_or_null("UiAnchor/CheckboxOmitirRanking")
	if checkbox != null:
		checkbox.visible = false


func _configurar_boton_continuar() -> void:
	if continuar_label != null:
		continuar_label.text = PostPartidaFlow.texto_boton_dashboard()


func _aplicar_estilo_sync() -> void:
	if label_sync_status == null:
		return
	label_sync_status.add_theme_color_override("font_color", Color(0.302, 0.322, 0.361, 0.9))
	label_sync_status.add_theme_font_size_override("font_size", 16)


func _leer_precision_real(stats: Dictionary) -> int:
	if stats.has("last_accuracy"):
		return int(stats.get("last_accuracy", 0))
	var intentos := int(stats.get("intentos", 0))
	if intentos > 0:
		return NodoProgressionRulesScript.calcular_precision_display(
			int(stats.get("aciertos", 0)),
			intentos
		)
	if stats.has("precision"):
		var precision := int(stats.get("precision", 0))
		if precision >= 100 and intentos <= 0:
			push_warning(
				"[FinalizaciónPartida] precision=100 con intentos=0; tratando como dato inválido."
			)
			return 0
		return precision
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

	if precision >= 100:
		if not audio_perfecto.playing:
			audio_perfecto.play()
	else:
		if not audio_normal.playing:
			audio_normal.play()


func _actualizar_titulo_leccion(precision: int) -> void:
	var titulo := get_node_or_null("LeccionCompleta") as Label
	if titulo == null:
		return
	if precision >= 100:
		titulo.text = "¡LECCIÓN PERFECTA!"
		titulo.add_theme_color_override("font_color", Color(0.859, 0.753, 0.318, 1))
	else:
		titulo.text = "¡LECCIÓN COMPLETA!"


func _construir_comparacion_precision(stats: Dictionary, precision_actual: int) -> Dictionary:
	var best: int = int(stats.get("best_accuracy", precision_actual))
	if best <= 0:
		best = precision_actual
	var best_clamped: int = clampi(best, 0, 100)
	var actual_clamped: int = clampi(precision_actual, 0, 100)
	return {
		"best_accuracy": best_clamped,
		"last_accuracy": actual_clamped,
		"texto": (
			"Tu mejor precisión fue %d%%\nTu precisión actual es %d%%"
			% [best_clamped, actual_clamped]
		),
	}


func obtener_comparacion_precision() -> Dictionary:
	return _comparacion_precision.duplicate(true)


func _mostrar_comparacion_precision(stats: Dictionary, precision_actual: int) -> void:
	_comparacion_precision = _construir_comparacion_precision(stats, precision_actual)
	if mensaje == null or not MOSTRAR_COMPARACION_PRECISION_UI:
		return
	mensaje.visible = true
	mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mensaje.text = str(_comparacion_precision.get("texto", ""))


func _prefetch_ranking_en_segundo_plano() -> void:
	PostPartidaFlow.prefetch_ranking_si_corresponde(get_tree())


func _on_continuar_presionado() -> void:
	PostPartidaFlow.continuar_desde_dashboard(get_tree())


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
