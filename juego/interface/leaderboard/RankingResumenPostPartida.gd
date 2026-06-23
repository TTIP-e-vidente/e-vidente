class_name RankingResumenPostPartida
extends PanelContainer

# Resumen compacto del ranking para la pantalla post-partida.
# La tabla (colores, layout, estados vacío/carga) vive en el .tscn para rediseño visual.
# Este script solo carga datos y alterna visibilidad de nodos ya definidos en escena.


signal ver_ranking_solicitado(scope: String)
signal iniciar_sesion_solicitado


@onready var _contenedor_carga: Label = %Cargando
@onready var _contenedor_datos: VBoxContainer = %VBoxRoot
@onready var _label_celebracion: Label = %LabelCelebracion
@onready var _label_scope: Label = %LabelScope
@onready var _label_puesto: Label = %LabelPuesto
@onready var _label_exp: Label = %LabelExp
@onready var _label_meta: Label = %LabelMeta
@onready var _mini_list: LeaderboardMiniList = %MiniList
@onready var _label_cargando_tabla: Label = %LabelCargandoTabla
@onready var _label_vacio_tabla: Label = %LabelVacioTabla
@onready var _boton_accion: Button = %BotonAccion
@onready var _etiqueta_top: Label = %EtiquetaTop
@onready var _titulo_seccion: Label = $VBoxRoot/HeaderBar/MarginHeader/HBoxHeader/TituloSeccion
@onready var _hbox_puesto: HBoxContainer = $VBoxRoot/MarginBody/VBoxBody/HBoxPuesto
@onready var _separador_mini: ColorRect = $VBoxRoot/MarginBody/VBoxBody/SeparadorMini

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
		_boton_accion.visible = false


func mostrar_invitacion_login() -> void:
	visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false
	if is_instance_valid(_contenedor_datos):
		_contenedor_datos.visible = true

	_ocultar_mensaje_celebracion()
	_aplicar_vista_invitado_compacta()


func cargar_tabla_invitado() -> void:
	if AuthApi.esta_logueado() or not is_instance_valid(_mini_list):
		return

	var scope := _scope_preferido
	if scope.is_empty():
		scope = LeaderboardApi.SCOPE_XP_GLOBAL

	_mostrar_carga_tabla(true)

	var datos := LeaderboardService.obtener_desde_cache(scope)
	if datos.is_empty():
		await LeaderboardService.cargar(scope, false)
		datos = LeaderboardService.obtener_desde_cache(scope)

	_mostrar_carga_tabla(false)

	if datos.is_empty():
		_mostrar_tabla_vacia("Ranking no disponible")
		return

	_poblar_tabla(datos, "")


func _aplicar_vista_invitado_compacta() -> void:
	if is_instance_valid(_titulo_seccion):
		_titulo_seccion.text = "Top jugadores"
	if is_instance_valid(_hbox_puesto):
		_hbox_puesto.visible = false
	if is_instance_valid(_label_meta):
		_label_meta.visible = false
		_label_meta.text = ""
	if is_instance_valid(_etiqueta_top):
		_etiqueta_top.visible = false
	if is_instance_valid(_separador_mini):
		_separador_mini.visible = false


func _aplicar_vista_jugador_registrado() -> void:
	if is_instance_valid(_titulo_seccion):
		_titulo_seccion.text = "Tu puesto en la tabla"
	if is_instance_valid(_hbox_puesto):
		_hbox_puesto.visible = true
	if is_instance_valid(_label_meta):
		_label_meta.visible = true
	if is_instance_valid(_etiqueta_top):
		_etiqueta_top.visible = false
	if is_instance_valid(_separador_mini):
		_separador_mini.visible = true


func mostrar_modo_invitado(scope: String = "") -> void:
	var scope_final := scope.strip_edges()
	if not scope_final.is_empty():
		_scope_preferido = scope_final
	if is_instance_valid(_label_scope):
		_label_scope.text = RestrictionCodes.etiqueta_scope(_scope_preferido)
	mostrar_invitacion_login()


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
	_aplicar_vista_jugador_registrado()

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

	_mostrar_carga_tabla(true)

	var id_propio := ""
	if AuthApi.esta_logueado():
		id_propio = str(BackendSession.obtener_usuario_en_cache().get("id", ""))

	if not _datos_resumen.is_empty() and _mini_list.poblar_desde_nearby(_datos_resumen, id_propio, scope):
		_mostrar_carga_tabla(false)
		_finalizar_tabla_visible()
		return

	var datos_cache := LeaderboardService.obtener_desde_cache(scope)
	if datos_cache.is_empty():
		await LeaderboardService.cargar(scope, true)
		datos_cache = LeaderboardService.obtener_desde_cache(scope)

	_mostrar_carga_tabla(false)

	if datos_cache.is_empty():
		_mostrar_tabla_vacia("Ranking no disponible")
		return

	_poblar_tabla(datos_cache, id_propio)


func _poblar_tabla(datos: Dictionary, id_propio: String) -> void:
	if not is_instance_valid(_mini_list):
		return
	if _puesto_actual > 0 and not _datos_resumen.is_empty():
		if not _mini_list.poblar_desde_nearby(_datos_resumen, id_propio, _scope_preferido):
			_mini_list.poblar_contexto_post_partida(
				datos,
				_datos_resumen,
				_puesto_actual,
				id_propio,
				2
			)
	else:
		_mini_list.poblar(datos, id_propio, _limite_filas_tabla())
	_finalizar_tabla_visible()


func _finalizar_tabla_visible() -> void:
	if not is_instance_valid(_mini_list) or _mini_list.get_child_count() == 0:
		_mostrar_tabla_vacia()
		return
	if is_instance_valid(_label_cargando_tabla):
		_label_cargando_tabla.visible = false
	if is_instance_valid(_label_vacio_tabla):
		_label_vacio_tabla.visible = false
	_mini_list.visible = true
	if is_instance_valid(_etiqueta_top):
		_etiqueta_top.visible = false


func _limite_filas_tabla() -> int:
	return _mini_list.max_filas if is_instance_valid(_mini_list) else 5


func _mostrar_carga_tabla(activo: bool) -> void:
	if is_instance_valid(_label_cargando_tabla):
		_label_cargando_tabla.visible = activo
	if is_instance_valid(_label_vacio_tabla) and activo:
		_label_vacio_tabla.visible = false
	if is_instance_valid(_mini_list):
		_mini_list.visible = not activo


func _mostrar_tabla_vacia(mensaje: String = "") -> void:
	if is_instance_valid(_mini_list):
		_mini_list.limpiar()
		_mini_list.visible = false
	if is_instance_valid(_label_cargando_tabla):
		_label_cargando_tabla.visible = false
	if is_instance_valid(_label_vacio_tabla):
		var texto := mensaje.strip_edges()
		if texto.is_empty():
			texto = "Sin jugadores en %s todavía" % RestrictionCodes.etiqueta_scope(_scope_preferido)
		_label_vacio_tabla.text = texto
		_label_vacio_tabla.visible = true


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
