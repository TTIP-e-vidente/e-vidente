class_name LeaderboardEntry
extends HBoxContainer

# Fila individual dentro de la lista del leaderboard.


signal entrada_presionada(id_usuario: String, entrada: Dictionary)


@export var color_fila_propia: Color = Color(MiPaleta.VERDE_BOSQUE.r, MiPaleta.VERDE_BOSQUE.g, MiPaleta.VERDE_BOSQUE.b, 0.14)


@onready var _avatar_badge: LeaderboardAvatarBadge = $AvatarBadge
@onready var _label_posicion: Label           = $RankLabel
@onready var _label_nombre:   Label           = $NombreLabel
@onready var _label_puntaje:  Label           = $ScoreLabel
@onready var _boton_area:     Button          = $BotonArea


var _id_usuario: String = ""
var _entrada: Dictionary = {}
var _scope: String = "global_xp"
var _resaltar_propia: bool = false


func _ready() -> void:
	if is_instance_valid(_boton_area):
		_boton_area.pressed.connect(_al_presionar_fila)


func _draw() -> void:
	if _resaltar_propia:
		draw_rect(Rect2(Vector2.ZERO, size), color_fila_propia)


func poblar(entrada: Dictionary, es_propio: bool = false, scope: String = "global_xp") -> void:
	_entrada = entrada
	_id_usuario = str(entrada.get("user_id", ""))
	_scope = scope
	_resaltar_propia = es_propio

	var posicion: int  = int(entrada.get("rank", 0))
	var puntaje: int   = int(entrada.get("score", 0))
	var nombre: String = _resolver_nombre(entrada)

	_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
	_label_nombre.text   = nombre
	_label_puntaje.text  = LeaderboardFormat.formatear_score(puntaje, scope)

	if is_instance_valid(_avatar_badge):
		_avatar_badge.mostrar_para_entrada(entrada, es_propio)

	_aplicar_color_posicion(posicion, es_propio)
	_aplicar_estilo_propia(es_propio)
	queue_redraw()


func _resolver_nombre(entrada: Dictionary) -> String:
	var nombre_visible: Variant = entrada.get("display_name", null)
	if nombre_visible != null and nombre_visible is String and not (nombre_visible as String).is_empty():
		return nombre_visible as String
	var nombre_usuario: Variant = entrada.get("username", "")
	return nombre_usuario as String if nombre_usuario is String else "—"


func _aplicar_color_posicion(posicion: int, _es_propio: bool) -> void:
	if not is_instance_valid(_label_posicion):
		return
	_label_posicion.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_posicion_tarjeta_clara(posicion)
	)


func _aplicar_estilo_propia(es_propio: bool) -> void:
	if es_propio:
		if is_instance_valid(_label_nombre):
			_label_nombre.add_theme_color_override(
				"font_color",
				Color(0.22, 0.38, 0.30, 1)
			)
		if is_instance_valid(_label_puntaje):
			_label_puntaje.add_theme_color_override(
				"font_color",
				Color(0.25882354, 0.47058824, 0.36862746, 1)
			)
	else:
		if is_instance_valid(_label_nombre):
			_label_nombre.remove_theme_color_override("font_color")
		if is_instance_valid(_label_puntaje):
			_label_puntaje.remove_theme_color_override("font_color")


func refrescar_avatar_si_coincide(user_id: String) -> void:
	if user_id.is_empty() or user_id != _id_usuario:
		return
	if is_instance_valid(_avatar_badge):
		_avatar_badge.mostrar_para_entrada(_entrada, _resaltar_propia)


func es_usuario(id_usuario: String) -> bool:
	return not id_usuario.is_empty() and _id_usuario == id_usuario


func animar_atencion() -> void:
	modulate = Color(1.15, 1.10, 0.88, 1.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	queue_redraw()


func _al_presionar_fila() -> void:
	if not _id_usuario.is_empty():
		entrada_presionada.emit(_id_usuario, _entrada)
