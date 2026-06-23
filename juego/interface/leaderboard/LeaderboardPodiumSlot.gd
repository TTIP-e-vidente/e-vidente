class_name LeaderboardPodiumSlot
extends VBoxContainer

# Casillero del podio (1°, 2° o 3°).


@export var altura_pedestal: int = 36
@export var escala_rank: float = 1.0
@export var avatar_size: int = 44
@export var color_pedestal: Color = Color(0.859, 0.753, 0.318, 0.22)
@export var color_borde_pedestal: Color = Color(0.859, 0.753, 0.318, 0.55)


@onready var _avatar: LeaderboardAvatarBadge = %AvatarBadge
@onready var _label_nombre: Label = %NombreLabel
@onready var _label_puntaje: Label = %ScoreLabel
@onready var _label_rank: Label = %RankLabel
@onready var _pedestal: PanelContainer = %Pedestal


var _entrada: Dictionary = {}
var _scope: String = "global_xp"
var _es_propio: bool = false


func _enter_tree() -> void:
	if is_instance_valid(_avatar):
		_avatar.avatar_size = avatar_size


func _ready() -> void:
	if is_instance_valid(_pedestal):
		_pedestal.custom_minimum_size.y = altura_pedestal
		_aplicar_estilo_pedestal()
	if is_instance_valid(_label_rank):
		_label_rank.add_theme_font_size_override("font_size", int(22 * escala_rank))


func limpiar() -> void:
	_entrada = {}
	visible = false
	if is_instance_valid(_label_nombre):
		_label_nombre.text = ""
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = ""
	if is_instance_valid(_label_rank):
		_label_rank.text = ""


func poblar(entrada: Dictionary, es_propio: bool, scope: String) -> void:
	if entrada.is_empty():
		limpiar()
		return

	_entrada = entrada
	_scope = scope
	_es_propio = es_propio
	visible = true

	var posicion := int(entrada.get("rank", 0))
	var puntaje := int(entrada.get("score", 0))
	var nombre := _resolver_nombre(entrada)

	if is_instance_valid(_label_rank):
		_label_rank.text = LeaderboardFormat.texto_posicion(posicion)
		_label_rank.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion(posicion, es_propio)
		)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = nombre
		if es_propio:
			_label_nombre.add_theme_color_override("font_color", Color.WHITE)
		else:
			_label_nombre.remove_theme_color_override("font_color")
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = LeaderboardFormat.formatear_score(puntaje, scope)
		if es_propio:
			_label_puntaje.add_theme_color_override("font_color", MiPaleta.ORO_CLARO)
		else:
			_label_puntaje.remove_theme_color_override("font_color")
	if is_instance_valid(_avatar):
		_avatar.mostrar_para_entrada(entrada, es_propio)
	_aplicar_estilo_pedestal()


func obtener_entrada() -> Dictionary:
	return _entrada


func refrescar_avatar_si_coincide(user_id: String) -> void:
	if user_id.is_empty() or user_id != str(_entrada.get("user_id", "")):
		return
	if is_instance_valid(_avatar):
		_avatar.mostrar_para_entrada(_entrada, _es_propio)


func _resolver_nombre(entrada: Dictionary) -> String:
	var display: Variant = entrada.get("display_name", null)
	if display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = entrada.get("username", "")
	return username as String if username is String else "—"


func _aplicar_estilo_pedestal() -> void:
	if not is_instance_valid(_pedestal):
		return
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = color_pedestal
	estilo.border_color = color_borde_pedestal
	estilo.set_border_width_all(1)
	estilo.corner_radius_top_left = 8
	estilo.corner_radius_top_right = 8
	estilo.corner_radius_bottom_left = 2
	estilo.corner_radius_bottom_right = 2
	_pedestal.add_theme_stylebox_override("panel", estilo)
