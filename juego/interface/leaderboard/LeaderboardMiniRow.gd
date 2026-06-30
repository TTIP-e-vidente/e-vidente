class_name LeaderboardMiniRow
extends PanelContainer

# Fila compacta para snippets del ranking (post-partida / perfil).


@export var avatar_size: int = 28
@export var tema_claro: bool = false


@onready var _avatar: LeaderboardAvatarBadge = %AvatarBadge
@onready var _label_posicion: Label = %RankLabel
@onready var _label_nombre: Label = %NombreLabel
@onready var _label_puntaje: Label = %ScoreLabel


var _panel_style: StyleBoxFlat
var _entrada: Dictionary = {}
var _id_usuario: String = ""
var _es_propio: bool = false


func _enter_tree() -> void:
	if is_instance_valid(_avatar):
		_avatar.avatar_size = avatar_size


func _ready() -> void:
	var base := get_theme_stylebox("panel") as StyleBoxFlat
	if base != null:
		_panel_style = base.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _panel_style)
	if not LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.connect(_al_avatar_cargado)


func _exit_tree() -> void:
	if LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.disconnect(_al_avatar_cargado)


func poblar(entrada: Dictionary, es_propio: bool, scope: String) -> void:
	_entrada = entrada
	_id_usuario = LeaderboardFormat.id_usuario_entrada(entrada)
	_es_propio = es_propio

	var posicion := LeaderboardFormat.entero_desde_json(entrada.get("rank", 0))
	var puntaje := LeaderboardFormat.entero_desde_json(entrada.get("score", 0))
	if is_instance_valid(_label_posicion):
		_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
		_label_posicion.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion(posicion, es_propio)
		)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = LeaderboardFormat.resolver_nombre_entrada(entrada)
		if es_propio and not tema_claro:
			_label_nombre.add_theme_color_override("font_color", Color.WHITE)
		elif es_propio:
			_label_nombre.add_theme_color_override("font_color", Color(0.22, 0.38, 0.30, 1))
		else:
			_label_nombre.remove_theme_color_override("font_color")
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = LeaderboardFormat.formatear_score(puntaje, scope)
		if es_propio and not tema_claro:
			_label_puntaje.add_theme_color_override("font_color", MiPaleta.ORO_CLARO)
		elif es_propio:
			_label_puntaje.add_theme_color_override("font_color", Color(0.25882354, 0.47058824, 0.36862746, 1))
		else:
			_label_puntaje.remove_theme_color_override("font_color")
	if is_instance_valid(_avatar):
		_avatar.mostrar_para_entrada(entrada, es_propio)
	_aplicar_resaltado_propia(es_propio)
	_aplicar_tema_etiquetas(es_propio)


func refrescar_avatar_si_coincide(user_id: String) -> void:
	if user_id.is_empty() or user_id != _id_usuario:
		return
	if is_instance_valid(_avatar):
		_avatar.mostrar_para_entrada(_entrada, _es_propio)


func animar_atencion() -> void:
	modulate = Color(1.12, 1.08, 0.92, 1.0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, 0.45)


func es_fila_propia() -> bool:
	return _es_propio


func es_usuario(id_usuario: String) -> bool:
	return not id_usuario.is_empty() and _id_usuario == id_usuario


func _aplicar_resaltado_propia(es_propio: bool) -> void:
	if _panel_style == null:
		return
	if tema_claro:
		if es_propio:
			_panel_style.bg_color = Color(0.259, 0.471, 0.369, 0.18)
			_panel_style.border_color = Color(0.259, 0.471, 0.369, 0.45)
		else:
			_panel_style.bg_color = Color(0.962, 0.957, 0.937, 1.0)
			_panel_style.border_color = Color(0.204, 0.247, 0.173, 0.10)
		return
	if es_propio:
		_panel_style.bg_color = Color(0.259, 0.471, 0.369, 0.35)
		_panel_style.border_color = Color(0.859, 0.753, 0.318, 0.55)
	else:
		_panel_style.bg_color = Color(0.06, 0.10, 0.08, 0.55)
		_panel_style.border_color = Color(0.859, 0.753, 0.318, 0.12)


func _aplicar_tema_etiquetas(es_propio: bool) -> void:
	if not tema_claro or es_propio:
		return
	if is_instance_valid(_label_nombre):
		_label_nombre.add_theme_color_override("font_color", Color(0.22, 0.25, 0.23, 1))
	if is_instance_valid(_label_puntaje):
		_label_puntaje.add_theme_color_override("font_color", Color(0.278, 0.251, 0.184, 0.75))
	if is_instance_valid(_label_posicion):
		_label_posicion.add_theme_color_override("font_color", Color(0.25882354, 0.47058824, 0.36862746, 1))


func _al_avatar_cargado(user_id: String, _texture: Texture2D) -> void:
	refrescar_avatar_si_coincide(user_id)
