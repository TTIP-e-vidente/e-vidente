class_name RankingResumenPostPartida
extends PanelContainer

# Resumen compacto del ranking para la pantalla post-partida.


signal ver_ranking_solicitado(scope: String)
signal iniciar_sesion_solicitado


@onready var _contenedor_carga: Control = %Cargando
@onready var _contenedor_datos: VBoxContainer = %VBoxRoot
@onready var _label_celebracion: Label = %LabelCelebracion
@onready var _label_scope: Label = %LabelScope
@onready var _label_puesto: Label = %LabelPuesto
@onready var _label_exp: Label = %LabelExp
@onready var _label_meta: Label = %LabelMeta
@onready var _mini_list: LeaderboardMiniList = %MiniList
@onready var _boton_accion: Button = %BotonAccion
@onready var _etiqueta_top: Label = %EtiquetaTop

var _scope_preferido: String = LeaderboardApi.SCOPE_XP_GLOBAL
var _puesto_actual: int = 0
var _datos_resumen: Dictionary = {}
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

	if is_instance_valid(_boton_accion):
		_boton_accion.pressed.connect(_al_presionar_accion)


func mostrar_invitacion_login() -> void:
	visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true

	_ocultar_mensaje_celebracion()
	_label_puesto.text = "—"
	_label_exp.text = ""
	_label_meta.text = "Iniciá sesión para ver tu puesto y el top del ranking."
	if is_instance_valid(_mini_list):
		_mini_list.limpiar()
	if is_instance_valid(_etiqueta_top):
		_etiqueta_top.text = "TOP DEL RANKING"
	if is_instance_valid(_boton_accion):
		_boton_accion.text = "Iniciar sesión"
	call_deferred("_cargar_top_global_invitado")


func mostrar_desde_datos(
	datos: Dictionary,
	puesto_antes_de_jugar: int = CelebracionSubidaRanking.PUESTO_NO_REGISTRADO
) -> void:
	if not datos.get("available", true):
		visible = false
		return

	visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true

	if is_instance_valid(_boton_accion):
		_boton_accion.text = "Ver tabla completa"

	var scope_datos := str(datos.get("scope", _scope_preferido)).strip_edges()
	if not scope_datos.is_empty():
		_scope_preferido = scope_datos

	var etiqueta_scope := str(
		datos.get("scope_label", RestrictionCodes.etiqueta_scope(_scope_preferido))
	)
	if is_instance_valid(_label_scope):
		_label_scope.text = etiqueta_scope

	var current: Variant = datos.get("current", {})
	if not current is Dictionary:
		visible = false
		return

	var puesto_despues := int((current as Dictionary).get("rank", 0))
	var exp_actual := int((current as Dictionary).get("score", 0))
	_puesto_actual = puesto_despues
	_datos_resumen = datos.duplicate(true)
	if is_instance_valid(_etiqueta_top):
		_etiqueta_top.text = "CERCA DE TU PUESTO"

	_label_puesto.text = LeaderboardFormat.texto_posicion(puesto_despues)
	_label_puesto.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_posicion(puesto_despues, false)
	)
	_label_exp.text = LeaderboardFormat.formatear_score(exp_actual, _scope_preferido)

	_mostrar_celebracion_si_subio(puesto_antes_de_jugar, puesto_despues, etiqueta_scope)
	_actualizar_meta(datos, etiqueta_scope)
	call_deferred("_cargar_mini_tabla", _scope_preferido)


func mostrar_estado_carga() -> void:
	visible = true
	_ocultar_mensaje_celebracion()
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = true
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = false


func _actualizar_meta(datos: Dictionary, etiqueta_scope: String) -> void:
	if bool(datos.get("is_first_place", false)):
		_label_meta.text = "¡Primero en %s!" % etiqueta_scope
		return

	var siguiente: Variant = datos.get("next", {})
	if siguiente is Dictionary:
		var faltante := LeaderboardFormat.formatear_score(
			int(datos.get("exp_to_next_rank", 0)),
			_scope_preferido
		)
		_label_meta.text = "Faltan %s para superar a %s" % [
			faltante,
			_nombre_rival(siguiente),
		]
	else:
		_label_meta.text = "Seguí jugando para escalar en %s" % etiqueta_scope


func _cargar_mini_tabla(scope: String) -> void:
	if not is_instance_valid(_mini_list):
		return

	var datos_cache := LeaderboardService.obtener_desde_cache(scope)
	if datos_cache.is_empty():
		_conectar_carga_mini_una_vez(scope)
		LeaderboardService.cargar(scope, true)
		return

	_poblar_mini_lista(datos_cache)


func _conectar_carga_mini_una_vez(scope: String) -> void:
	if LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_para_mini):
		return
	LeaderboardService.leaderboard_cargado.connect(
		func(scope_cargado: String, datos: Dictionary) -> void:
			if scope_cargado == scope or scope_cargado.ends_with(":mas"):
				_al_leaderboard_para_mini(scope_cargado, datos),
		CONNECT_ONE_SHOT
	)


func _al_leaderboard_para_mini(scope_cargado: String, datos: Dictionary) -> void:
	if scope_cargado.ends_with(":mas"):
		return
	if str(datos.get("scope", "")) != _scope_preferido:
		return
	_poblar_mini_lista(datos)


func _poblar_mini_lista(datos: Dictionary) -> void:
	if not is_instance_valid(_mini_list):
		return
	var id_propio := ""
	if AuthApi.esta_logueado():
		id_propio = str(BackendSession.obtener_usuario_en_cache().get("id", ""))
	if _puesto_actual > 0 and not _datos_resumen.is_empty():
		_mini_list.poblar_contexto_post_partida(
			datos,
			_datos_resumen,
			_puesto_actual,
			id_propio,
			2
		)
	else:
		_mini_list.poblar(datos, id_propio, 3)


func _cargar_top_global_invitado() -> void:
	if AuthApi.esta_logueado() or not is_instance_valid(_mini_list):
		return

	var scope := LeaderboardApi.SCOPE_XP_GLOBAL
	var datos := LeaderboardService.obtener_desde_cache(scope)
	if datos.is_empty():
		if not LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_invitado):
			LeaderboardService.leaderboard_cargado.connect(_al_leaderboard_invitado, CONNECT_ONE_SHOT)
		LeaderboardService.cargar(scope, false)
		return

	_mini_list.poblar(datos, "", 3)


func _al_leaderboard_invitado(scope_cargado: String, datos: Dictionary) -> void:
	if scope_cargado.ends_with(":mas"):
		return
	if not is_instance_valid(_mini_list) or AuthApi.esta_logueado():
		return
	_mini_list.poblar(datos, "", 3)


func _mostrar_celebracion_si_subio(
	puesto_antes: int,
	puesto_despues: int,
	etiqueta_categoria: String
) -> void:
	var resultado := CelebracionSubidaRanking.calcular_desde_partida(
		puesto_antes,
		puesto_despues,
		etiqueta_categoria
	)
	if not bool(resultado.get("mostrar_celebracion", false)):
		_ocultar_mensaje_celebracion()
		return

	var mensaje := str(resultado.get("mensaje_celebracion", "")).strip_edges()
	if mensaje.is_empty() or not is_instance_valid(_label_celebracion):
		_ocultar_mensaje_celebracion()
		return

	_label_celebracion.text = mensaje
	_label_celebracion.visible = true
	var puestos := int(resultado.get("cantidad_puestos_ganados", 0))
	var es_primera := bool(resultado.get("es_primera_aparicion_en_ranking", false))
	_animar_celebracion(puestos, es_primera)


func _animar_celebracion(puestos_ganados: int, es_primera: bool) -> void:
	if not is_instance_valid(_label_celebracion):
		return

	await get_tree().process_frame
	_detener_animacion_borde()

	var intensidad := 1
	if es_primera:
		intensidad = 2
	elif puestos_ganados >= 5:
		intensidad = 3
	elif puestos_ganados >= 3:
		intensidad = 2

	_label_celebracion.modulate.a = 0.0
	_label_celebracion.scale = Vector2(0.85, 0.85)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label_celebracion, "modulate:a", 1.0, 0.4)
	tween.tween_property(_label_celebracion, "scale", Vector2.ONE, 0.4)
	_pulso_borde_celebracion(intensidad)


func _ocultar_mensaje_celebracion() -> void:
	if is_instance_valid(_label_celebracion):
		_label_celebracion.visible = false
		_label_celebracion.text = ""


func _pulso_borde_celebracion(intensidad: int) -> void:
	if _estilo_panel_base == null:
		return
	_detener_animacion_borde()

	var borde := _estilo_panel_base.duplicate() as StyleBoxFlat
	borde.border_color = MiPaleta.ORO_CLARO
	borde.set_border_width_all(3 if intensidad >= 2 else 2)
	borde.bg_color = Color(
		MiPaleta.ORO_CLARO.r,
		MiPaleta.ORO_CLARO.g,
		MiPaleta.ORO_CLARO.b,
		0.1
	)

	var ciclos := 2 + intensidad
	_tween_celebracion_borde = create_tween().set_loops(ciclos)
	_tween_celebracion_borde.tween_callback(func() -> void: add_theme_stylebox_override("panel", borde))
	_tween_celebracion_borde.tween_interval(0.14)
	_tween_celebracion_borde.tween_callback(func() -> void: add_theme_stylebox_override("panel", _estilo_panel_base))
	_tween_celebracion_borde.tween_interval(0.14)
	_tween_celebracion_borde.finished.connect(_restaurar_estilo_panel)


func _detener_animacion_borde() -> void:
	if _tween_celebracion_borde != null and _tween_celebracion_borde.is_valid():
		_tween_celebracion_borde.kill()
	_tween_celebracion_borde = null
	_restaurar_estilo_panel()


func _restaurar_estilo_panel() -> void:
	if _estilo_panel_base != null:
		add_theme_stylebox_override("panel", _estilo_panel_base)


func _al_presionar_accion() -> void:
	if not AuthApi.esta_logueado():
		iniciar_sesion_solicitado.emit()
		return
	ver_ranking_solicitado.emit(_scope_preferido)


func _nombre_rival(siguiente: Variant) -> String:
	if not siguiente is Dictionary:
		return "el anterior"
	var sig := siguiente as Dictionary
	var display: Variant = sig.get("display_name", null)
	if display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = sig.get("username", "")
	if username is String and not (username as String).is_empty():
		return username as String
	var puesto := int(sig.get("rank", 0))
	return "puesto #%d" % puesto if puesto > 0 else "el anterior"
