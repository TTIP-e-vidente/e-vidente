class_name LeaderboardPosicionHubCard
extends Button

# Card compacta con posición del jugador en un scope del hub.


signal scope_presionado(scope: String)


@onready var _label_etiqueta: Label = %EtiquetaScope
@onready var _label_posicion: Label = %PosicionLabel
@onready var _label_puntaje: Label = %ScoreLabel


var _scope: String = ""
var _rank_actual: int = 0
var _estilo_normal: StyleBox
var _estilo_hover: StyleBox
var _estilo_destacada: StyleBoxFlat

const _COLOR_ETIQUETA := Color(0.22, 0.38, 0.30, 0.9)


func _ready() -> void:
	pressed.connect(_al_presionar)
	_estilo_normal = get_theme_stylebox("normal")
	_estilo_hover = get_theme_stylebox("hover")
	_estilo_destacada = _crear_estilo_destacada()


func configurar(etiqueta: String, scope: String, rank: int, score: int) -> void:
	_scope = scope
	_rank_actual = rank
	if is_instance_valid(_label_etiqueta):
		_label_etiqueta.text = etiqueta
		_label_etiqueta.add_theme_color_override("font_color", _COLOR_ETIQUETA)

	_aplicar_contenido_ranking(rank, score, scope)


func marcar_cargando(etiqueta: String, scope: String) -> void:
	_scope = scope
	_rank_actual = 0
	marcar_destacada(false)
	if is_instance_valid(_label_etiqueta):
		_label_etiqueta.text = etiqueta
		_label_etiqueta.add_theme_color_override("font_color", _COLOR_ETIQUETA)
	if is_instance_valid(_label_posicion):
		_label_posicion.visible = true
		_label_posicion.text = "..."
		_label_posicion.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_texto_secundario_tarjeta()
		)
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = ""
		_label_puntaje.visible = false


func marcar_destacada(activo: bool) -> void:
	if _estilo_normal == null or _estilo_hover == null:
		return
	if activo:
		add_theme_stylebox_override("normal", _estilo_destacada)
		add_theme_stylebox_override("hover", _estilo_destacada)
		add_theme_stylebox_override("pressed", _estilo_destacada)
	else:
		add_theme_stylebox_override("normal", _estilo_normal)
		add_theme_stylebox_override("hover", _estilo_hover)
		add_theme_stylebox_override("pressed", _estilo_hover)


func obtener_rank() -> int:
	return _rank_actual


func _aplicar_contenido_ranking(rank: int, score: int, scope: String) -> void:
	if not is_instance_valid(_label_posicion) or not is_instance_valid(_label_puntaje):
		return

	if rank > 0:
		_label_posicion.visible = true
		_label_posicion.text = LeaderboardFormat.texto_posicion(rank)
		_label_posicion.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion_tarjeta_clara(rank)
		)
		_label_puntaje.visible = true
		_label_puntaje.text = LeaderboardFormat.formatear_score(score, scope)
		_label_puntaje.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_texto_secundario_tarjeta()
		)
		return

	_label_posicion.visible = false
	_label_puntaje.visible = true
	_label_puntaje.text = LeaderboardFormat.mensaje_sin_ranking(scope)
	_label_puntaje.add_theme_color_override(
		"font_color",
		LeaderboardFormat.color_texto_secundario_tarjeta()
	)


func _crear_estilo_destacada() -> StyleBoxFlat:
	var base := _estilo_normal as StyleBoxFlat
	var estilo := base.duplicate() as StyleBoxFlat if base != null else StyleBoxFlat.new()
	estilo.bg_color = Color(0.98, 0.96, 0.90, 1.0)
	estilo.border_color = Color(0.859, 0.753, 0.318, 0.85)
	estilo.set_border_width_all(2)
	return estilo


func _al_presionar() -> void:
	if not _scope.is_empty():
		scope_presionado.emit(_scope)
