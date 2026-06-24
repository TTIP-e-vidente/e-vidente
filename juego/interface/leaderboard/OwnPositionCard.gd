class_name OwnPositionCard
extends PanelContainer

# Tarjeta fija que muestra la posición del jugador logueado en el ranking.


signal iniciar_sesion_solicitado
signal ir_a_posicion_solicitada(rank: int)
signal volver_al_top_solicitado


@onready var _label_posicion: Label = $MarginContainer/HBox/RankLabel
@onready var _label_puntaje:  Label = $MarginContainer/HBox/ScoreLabel
@onready var _label_texto:    Label = $MarginContainer/HBox/TextoLabel
@onready var _nav_botones:    HBoxContainer = %NavBotones
@onready var _boton_iniciar_sesion: Button = $MarginContainer/HBox/BotonIniciarSesion
@onready var _boton_ir_posicion: Button = %BotonIrPosicion
@onready var _boton_volver_top: Button = %BotonVolverTop


var _scope_pendiente: String = "global_xp"
var _rank_actual: int = 0
var _texto_ir_original: String = "Ir a mi fila"


func _ready() -> void:
	visible = false
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false
		_boton_iniciar_sesion.pressed.connect(func() -> void: iniciar_sesion_solicitado.emit())
	if is_instance_valid(_boton_ir_posicion):
		_texto_ir_original = _boton_ir_posicion.text
		_boton_ir_posicion.visible = false
		_boton_ir_posicion.pressed.connect(_al_presionar_ir_posicion)
	if is_instance_valid(_boton_volver_top):
		_boton_volver_top.visible = false
		_boton_volver_top.pressed.connect(_al_presionar_volver_top)
	if is_instance_valid(_nav_botones):
		_nav_botones.visible = false


func configurar_navegacion(rank: int, visible_en_lista: bool, offset_lista: int = 0) -> void:
	_rank_actual = rank
	_restaurar_boton_ir()
	_ocultar_navegacion()

	if rank <= 0 or not AuthApi.esta_logueado():
		return

	var mostrar_nav := false
	if offset_lista > 0 and is_instance_valid(_boton_volver_top):
		_boton_volver_top.visible = true
		mostrar_nav = true
	if rank > 3 and not visible_en_lista and is_instance_valid(_boton_ir_posicion):
		_boton_ir_posicion.visible = true
		_boton_ir_posicion.text = "Ir a %s" % LeaderboardFormat.texto_posicion(rank)
		mostrar_nav = true

	if is_instance_valid(_nav_botones):
		_nav_botones.visible = mostrar_nav


func configurar_accion_ir_posicion(rank: int, visible_en_lista: bool) -> void:
	configurar_navegacion(rank, visible_en_lista, 0)


func marcar_buscando_posicion(activo: bool) -> void:
	if not is_instance_valid(_boton_ir_posicion):
		return
	_boton_ir_posicion.disabled = activo
	_boton_ir_posicion.text = "Buscando..." if activo else _texto_ir_para_rank(_rank_actual)


func _texto_ir_para_rank(rank: int) -> String:
	if rank <= 0:
		return _texto_ir_original
	return "Ir a %s" % LeaderboardFormat.texto_posicion(rank)


func _restaurar_boton_ir() -> void:
	if is_instance_valid(_boton_ir_posicion):
		_boton_ir_posicion.disabled = false


func _ocultar_navegacion() -> void:
	if is_instance_valid(_boton_ir_posicion):
		_boton_ir_posicion.visible = false
	if is_instance_valid(_boton_volver_top):
		_boton_volver_top.visible = false
	if is_instance_valid(_nav_botones):
		_nav_botones.visible = false


func _al_presionar_ir_posicion() -> void:
	if _rank_actual > 0:
		ir_a_posicion_solicitada.emit(_rank_actual)


func _al_presionar_volver_top() -> void:
	volver_al_top_solicitado.emit()


func _ocultar_boton_iniciar_sesion() -> void:
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false


func mostrar_modo_solo_lectura() -> void:
	visible = true
	_rank_actual = 0
	_ocultar_navegacion()
	_label_posicion.text = "—"
	_label_puntaje.text = ""
	_label_texto.text = LeaderboardFormat.texto_tarjeta_modo_invitado()
	_label_posicion.remove_theme_color_override("font_color")
	_ocultar_boton_iniciar_sesion()


func mostrar_invitacion_login() -> void:
	mostrar_modo_solo_lectura()


func mostrar_desde_respuesta_leaderboard(scope: String, datos: Dictionary) -> void:
	if not AuthApi.esta_logueado():
		mostrar_modo_solo_lectura()
		return

	_ocultar_boton_iniciar_sesion()

	_scope_pendiente = scope
	var own: Variant = datos.get("own_position", null)
	if own is Dictionary:
		var own_dict := own as Dictionary
		if own_dict.get("rank") != null:
			visible = true
			_rank_actual = int(own_dict.get("rank", 0))
			_mostrar_posicion(_rank_actual, int(own_dict.get("score", 0)))
			return

	var id_propio := _obtener_id_usuario_logueado()
	for entrada in datos.get("entries", []) as Array:
		if entrada is Dictionary:
			var entry := entrada as Dictionary
			if str(entry.get("user_id", "")) == id_propio:
				visible = true
				_rank_actual = int(entry.get("rank", 0))
				_mostrar_posicion(_rank_actual, int(entry.get("score", 0)))
				return

	visible = true
	_rank_actual = 0
	_mostrar_sin_rankear()


func cargar_y_mostrar(scope: String, forzar: bool = false) -> void:
	if not AuthApi.esta_logueado():
		mostrar_invitacion_login()
		return
	_ocultar_boton_iniciar_sesion()
	_scope_pendiente = scope
	LeaderboardService.cargar_posicion_propia(forzar)


func mostrar_para_scope(scope: String, posiciones: Array) -> void:
	if not AuthApi.esta_logueado():
		mostrar_invitacion_login()
		return

	_ocultar_boton_iniciar_sesion()

	visible = true
	_scope_pendiente = scope
	var posicion: Dictionary = _buscar_posicion_para_scope(scope, posiciones)

	if posicion.is_empty() or posicion.get("rank") == null:
		_mostrar_sin_rankear()
		return

	_rank_actual = int(posicion.get("rank", 0))
	_mostrar_posicion(_rank_actual, int(posicion.get("score", 0)))


func _mostrar_posicion(posicion: int, puntaje: int) -> void:
	_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
	_label_puntaje.text  = LeaderboardFormat.formatear_score(puntaje, _scope_pendiente)
	_label_texto.text    = "Tu posición"
	_label_posicion.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_posicion_tarjeta_clara(posicion)
	)


func _mostrar_sin_rankear() -> void:
	_label_posicion.text = "—"
	_label_puntaje.text  = ""
	_label_texto.text    = "Jugá para aparecer en el ranking"
	_label_posicion.remove_theme_color_override("font_color")


func _buscar_posicion_para_scope(scope: String, posiciones: Array) -> Dictionary:
	for posicion in posiciones:
		if posicion is Dictionary and str(posicion.get("scope", "")) == scope:
			return posicion as Dictionary
	return {}


func _obtener_id_usuario_logueado() -> String:
	var datos_usuario := BackendSession.obtener_usuario_en_cache()
	return str(datos_usuario.get("id", ""))
