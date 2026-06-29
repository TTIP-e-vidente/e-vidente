class_name ProgresoPuestoCard
extends PanelContainer

# Tarjeta detallada de progreso competitivo (perfil / contexto expandido).


signal ver_ranking_solicitado(scope: String)


@onready var _label_celebracion: Label = %LabelCelebracion
@onready var _label_puesto: Label = %LabelPuesto
@onready var _label_exp: Label = %LabelExp
@onready var _label_meta: Label = %LabelMeta
@onready var _barra_progreso: ProgressBar = %BarraProgreso
@onready var _boton_ver_ranking: Button = %BotonVerRanking
@onready var _contenedor_carga: Label = %Cargando
@onready var _contenedor_datos: MarginContainer = %MarginContainer

var _cargando: bool = false
var _scope_preferido: String = LeaderboardApi.SCOPE_XP_GLOBAL
var _estilo_panel_base: StyleBoxFlat = null
var _tween_celebracion_borde: Tween = null


func _ready() -> void:
	var base := get_theme_stylebox("panel") as StyleBoxFlat
	if base != null:
		_estilo_panel_base = base.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _estilo_panel_base)

	_ocultar_mensaje_celebracion()
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = false

	if is_instance_valid(_boton_ver_ranking):
		_boton_ver_ranking.pressed.connect(_al_presionar_boton_inferior)


func cargar_y_mostrar(scope: String = LeaderboardApi.SCOPE_XP_GLOBAL, forzar: bool = false) -> void:
	_scope_preferido = scope.strip_edges()
	if _scope_preferido.is_empty():
		_scope_preferido = LeaderboardApi.SCOPE_XP_GLOBAL

	if _cargando:
		return
	if not AuthApi.esta_logueado():
		mostrar_invitacion_login()
		return

	if not forzar:
		var cacheado := LeaderboardService.obtener_resumen_desde_cache(_scope_preferido)
		if not cacheado.is_empty():
			if bool(cacheado.get("available", false)):
				mostrar_desde_datos(cacheado)
			else:
				mostrar_scope_sin_progreso(_scope_preferido, cacheado)
			return

	_cargando = true
	_mostrar_estado_carga()

	var resultado := await LeaderboardService.cargar_resumen_competitivo(forzar, _scope_preferido)
	_cargando = false

	if not resultado.get("ok", false):
		visible = false
		return

	var datos: Variant = resultado.get("data", resultado)
	if datos is Dictionary:
		var datos_dict := datos as Dictionary
		if bool(datos_dict.get("available", false)):
			mostrar_desde_datos(datos_dict)
		else:
			mostrar_scope_sin_progreso(_scope_preferido, datos_dict)
	else:
		visible = false


func mostrar_desde_datos(
	datos: Dictionary,
	puesto_antes_de_jugar: int = CelebracionSubidaRanking.PUESTO_NO_REGISTRADO
) -> void:
	if not datos.get("available", true):
		visible = false
		return

	visible = true
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false

	_label_puesto.visible = true
	_label_exp.visible = true
	if is_instance_valid(_boton_ver_ranking):
		_boton_ver_ranking.visible = true
		_boton_ver_ranking.text = "Ver ranking completo"

	var scope_datos := str(datos.get("scope", _scope_preferido)).strip_edges()
	if not scope_datos.is_empty():
		_scope_preferido = scope_datos

	var etiqueta_scope := str(datos.get("scope_label", RestrictionCodes.etiqueta_scope(_scope_preferido)))
	var es_primero: bool = bool(datos.get("is_first_place", false))
	var current: Variant = datos.get("current", {})
	if not current is Dictionary:
		visible = false
		return

	var puesto_despues_de_jugar: int = LeaderboardFormat.entero_desde_json(
		(current as Dictionary).get("rank", 0)
	)
	var exp_actual: int = LeaderboardFormat.entero_desde_json(
		(current as Dictionary).get("score", 0)
	)
	var exp_faltante: int = LeaderboardFormat.entero_desde_json(datos.get("exp_to_next_rank", 0))
	var progreso: float = float(datos.get("progress_to_next_rank", 0))

	_label_puesto.text = LeaderboardFormat.texto_posicion(puesto_despues_de_jugar)
	_label_puesto.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_posicion(puesto_despues_de_jugar, false)
	)

	_mostrar_celebracion_si_subio_en_ranking(
		puesto_antes_de_jugar,
		puesto_despues_de_jugar,
		etiqueta_scope
	)

	if es_primero:
		_label_meta.text = "¡Primero en %s!" % etiqueta_scope
	else:
		var siguiente: Variant = datos.get("next", {})
		var nombre_rival := _nombre_rival(siguiente)
		var faltante := LeaderboardFormat.formatear_score(exp_faltante, _scope_preferido)
		_label_meta.text = "En %s: faltan %s para superar a %s" % [
			etiqueta_scope,
			faltante,
			nombre_rival,
		]

	_animar_valores(exp_actual, progreso)
	if is_instance_valid(_barra_progreso):
		_barra_progreso.visible = not es_primero and progreso > 0.0


func _animar_valores(exp_meta: int, progreso_meta: float) -> void:
	_label_exp.text = LeaderboardFormat.formatear_xp(0)
	if is_instance_valid(_barra_progreso):
		_barra_progreso.min_value = 0.0
		_barra_progreso.max_value = 100.0
		_barra_progreso.value = 0.0

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_barra_progreso):
		tween.tween_property(_barra_progreso, "value", progreso_meta, 1.0)
	tween.tween_method(_setear_texto_exp_animado, 0, exp_meta, 1.0)


func _setear_texto_exp_animado(valor_actual: int) -> void:
	if is_instance_valid(_label_exp):
		_label_exp.text = LeaderboardFormat.formatear_score(valor_actual, _scope_preferido)


func _mostrar_celebracion_si_subio_en_ranking(
	puesto_antes_de_jugar: int,
	puesto_despues_de_jugar: int,
	etiqueta_categoria_ranking: String
) -> void:
	var resultado_celebracion := CelebracionSubidaRanking.calcular_desde_partida(
		puesto_antes_de_jugar,
		puesto_despues_de_jugar,
		etiqueta_categoria_ranking
	)

	if not bool(resultado_celebracion.get("mostrar_celebracion", false)):
		_ocultar_mensaje_celebracion()
		return

	var mensaje := str(resultado_celebracion.get("mensaje_celebracion", "")).strip_edges()
	if mensaje.is_empty() or not is_instance_valid(_label_celebracion):
		_ocultar_mensaje_celebracion()
		return

	_label_celebracion.text = mensaje
	_label_celebracion.visible = true
	var puestos_ganados := int(resultado_celebracion.get("cantidad_puestos_ganados", 0))
	var es_primera := bool(resultado_celebracion.get("es_primera_aparicion_en_ranking", false))
	_animar_celebracion_subida_ranking(puestos_ganados, es_primera)


func _ocultar_mensaje_celebracion() -> void:
	if is_instance_valid(_label_celebracion):
		_label_celebracion.visible = false
		_label_celebracion.text = ""


func _animar_celebracion_subida_ranking(puestos_ganados: int, es_primera_aparicion: bool) -> void:
	if not is_instance_valid(_label_celebracion):
		return

	await get_tree().process_frame
	_detener_animacion_borde_celebracion()

	var intensidad := 1
	if es_primera_aparicion:
		intensidad = 2
	elif puestos_ganados >= 5:
		intensidad = 3
	elif puestos_ganados >= 3:
		intensidad = 2

	var font_size := 16 if intensidad < 3 else 18
	_label_celebracion.add_theme_font_size_override("font_size", font_size)
	_label_celebracion.modulate = Color(1, 1, 1, 0.0)
	_label_celebracion.scale = Vector2(0.85, 0.85)

	var tween_label := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_label.tween_property(_label_celebracion, "modulate", Color.WHITE, 0.42)
	var escala := Vector2(1.06, 1.06) if intensidad >= 2 else Vector2(1.03, 1.03)
	tween_label.tween_property(_label_celebracion, "scale", escala, 0.42)

	if is_instance_valid(_label_puesto):
		var tween_puesto := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var escala_puesto := 1.15 if intensidad >= 3 else 1.1
		tween_puesto.tween_property(_label_puesto, "scale", Vector2(escala_puesto, escala_puesto), 0.28)
		tween_puesto.tween_property(_label_puesto, "scale", Vector2.ONE, 0.32)

	_pulso_borde_celebracion(intensidad)


func _mostrar_estado_carga() -> void:
	_ocultar_mensaje_celebracion()
	_detener_animacion_borde_celebracion()
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = true
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = false


func mostrar_invitacion_login() -> void:
	visible = true
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false

	_label_puesto.text = "—"
	_label_puesto.visible = false
	_label_puesto.remove_theme_color_override("font_color")
	_label_exp.text = ""
	_label_exp.visible = false
	_label_meta.text = LeaderboardFormat.mensaje_progreso_no_suma()
	if is_instance_valid(_barra_progreso):
		_barra_progreso.visible = false
		_barra_progreso.value = 0.0
	if is_instance_valid(_boton_ver_ranking):
		_boton_ver_ranking.visible = false


func mostrar_scope_sin_progreso(scope: String, datos: Dictionary = {}) -> void:
	visible = true
	_ocultar_mensaje_celebracion()
	_detener_animacion_borde_celebracion()
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false

	var scope_datos := str(datos.get("scope", scope)).strip_edges()
	if not scope_datos.is_empty():
		_scope_preferido = scope_datos

	var etiqueta := str(
		datos.get("scope_label", RestrictionCodes.etiqueta_scope(_scope_preferido))
	)
	_label_puesto.text = "—"
	_label_puesto.visible = false
	_label_puesto.remove_theme_color_override("font_color")
	_label_exp.text = ""
	_label_exp.visible = false
	_label_meta.text = LeaderboardFormat.mensaje_scope_sin_progreso(_scope_preferido, etiqueta)
	if is_instance_valid(_barra_progreso):
		_barra_progreso.visible = false
		_barra_progreso.value = 0.0
	if is_instance_valid(_boton_ver_ranking):
		_boton_ver_ranking.visible = true
		_boton_ver_ranking.text = "Ver ranking completo"


func _al_presionar_boton_inferior() -> void:
	ver_ranking_solicitado.emit(_scope_preferido)


func _nombre_rival(siguiente: Variant) -> String:
	if not siguiente is Dictionary:
		return "el jugador anterior"
	var sig := siguiente as Dictionary
	var display: Variant = sig.get("display_name", null)
	if display != null and display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = sig.get("username", "")
	if username is String and not (username as String).is_empty():
		return username as String
	var puesto: int = int(sig.get("rank", 0))
	return "puesto #%d" % puesto if puesto > 0 else "el jugador anterior"


func _pulso_borde_celebracion(intensidad: int) -> void:
	if _estilo_panel_base == null:
		return

	_detener_animacion_borde_celebracion()

	var borde_destello := _estilo_panel_base.duplicate() as StyleBoxFlat
	borde_destello.border_color = MiPaleta.ORO_CLARO
	borde_destello.set_border_width_all(3 if intensidad >= 2 else 2)
	borde_destello.bg_color = Color(
		MiPaleta.ORO_CLARO.r,
		MiPaleta.ORO_CLARO.g,
		MiPaleta.ORO_CLARO.b,
		0.08 if intensidad < 3 else 0.12
	)

	var ciclos := 2 + intensidad
	_tween_celebracion_borde = create_tween().set_loops(ciclos)
	_tween_celebracion_borde.tween_callback(func() -> void:
		add_theme_stylebox_override("panel", borde_destello)
	)
	_tween_celebracion_borde.tween_interval(0.14)
	_tween_celebracion_borde.tween_callback(func() -> void:
		add_theme_stylebox_override("panel", _estilo_panel_base)
	)
	_tween_celebracion_borde.tween_interval(0.14)
	_tween_celebracion_borde.finished.connect(_restaurar_estilo_panel_base)


func _detener_animacion_borde_celebracion() -> void:
	if _tween_celebracion_borde != null and _tween_celebracion_borde.is_valid():
		_tween_celebracion_borde.kill()
	_tween_celebracion_borde = null
	_restaurar_estilo_panel_base()


func _restaurar_estilo_panel_base() -> void:
	if _estilo_panel_base != null:
		add_theme_stylebox_override("panel", _estilo_panel_base)
	scale = Vector2.ONE
