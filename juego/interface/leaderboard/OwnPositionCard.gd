class_name OwnPositionCard
extends PanelContainer

# Tarjeta fija que muestra la posición del jugador logueado en el ranking.


signal iniciar_sesion_solicitado


const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"


@onready var _label_posicion: Label = $MarginContainer/HBox/RankLabel
@onready var _label_puntaje:  Label = $MarginContainer/HBox/ScoreLabel
@onready var _label_texto:    Label = $MarginContainer/HBox/TextoLabel
@onready var _boton_iniciar_sesion: Button = $MarginContainer/HBox/BotonIniciarSesion


var _scope_pendiente: String = "global_xp"


func _ready() -> void:
	visible = false
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false
		_boton_iniciar_sesion.pressed.connect(func() -> void: iniciar_sesion_solicitado.emit())
	_aplicar_fuente()


func _aplicar_fuente() -> void:
	var rubik: Font = load(RUBIK_FONT_PATH) as Font
	if rubik == null:
		return
	for lbl: Label in [_label_posicion, _label_puntaje, _label_texto]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", rubik)
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.add_theme_font_override("font", rubik)


func _ocultar_boton_iniciar_sesion() -> void:
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false


func mostrar_invitacion_login() -> void:
	visible = true
	_label_posicion.text = "—"
	_label_puntaje.text = ""
	_label_texto.text = "Sin sesión activa"
	_label_posicion.remove_theme_color_override("font_color")
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = true


func mostrar_desde_respuesta_leaderboard(scope: String, datos: Dictionary) -> void:
	if not AuthApi.esta_logueado():
		mostrar_invitacion_login()
		return

	_ocultar_boton_iniciar_sesion()

	_scope_pendiente = scope
	var own: Variant = datos.get("own_position", null)
	if own is Dictionary:
		var own_dict := own as Dictionary
		if own_dict.get("rank") != null:
			visible = true
			_mostrar_posicion(int(own_dict.get("rank", 0)), int(own_dict.get("score", 0)))
			return

	var id_propio := _obtener_id_usuario_logueado()
	for entrada in datos.get("entries", []) as Array:
		if entrada is Dictionary:
			var entry := entrada as Dictionary
			if str(entry.get("user_id", "")) == id_propio:
				visible = true
				_mostrar_posicion(int(entry.get("rank", 0)), int(entry.get("score", 0)))
				return

	visible = true
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

	_mostrar_posicion(int(posicion.get("rank", 0)), int(posicion.get("score", 0)))


func _mostrar_posicion(posicion: int, puntaje: int) -> void:
	_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
	_label_puntaje.text  = LeaderboardFormat.formatear_score(puntaje, _scope_pendiente)
	_label_texto.text    = "Tu posición"
	_label_posicion.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_posicion(posicion, false)
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
