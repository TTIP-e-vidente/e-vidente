class_name LeaderboardMiniRow
extends PanelContainer

# Fila compacta para snippets del ranking (post-partida / perfil).


@onready var _label_posicion: Label = %RankLabel
@onready var _label_nombre: Label = %NombreLabel
@onready var _label_puntaje: Label = %ScoreLabel

var _panel_style: StyleBoxFlat


func _ready() -> void:
	var base := get_theme_stylebox("panel") as StyleBoxFlat
	if base != null:
		_panel_style = base.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _panel_style)


func poblar(entrada: Dictionary, es_propio: bool, scope: String) -> void:
	var posicion := int(entrada.get("rank", 0))
	var puntaje := int(entrada.get("score", 0))
	if is_instance_valid(_label_posicion):
		_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
		_label_posicion.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion(posicion, es_propio)
		)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = _resolver_nombre(entrada)
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
	_aplicar_resaltado_propia(es_propio)


func _aplicar_resaltado_propia(es_propio: bool) -> void:
	if _panel_style == null:
		return
	if es_propio:
		_panel_style.bg_color = Color(0.259, 0.471, 0.369, 0.35)
		_panel_style.border_color = Color(0.859, 0.753, 0.318, 0.55)
	else:
		_panel_style.bg_color = Color(0.06, 0.10, 0.08, 0.55)
		_panel_style.border_color = Color(0.859, 0.753, 0.318, 0.12)


func _resolver_nombre(entrada: Dictionary) -> String:
	var display: Variant = entrada.get("display_name", null)
	if display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = entrada.get("username", "")
	return username as String if username is String else "—"
