class_name LeaderboardEntryPeek
extends PanelContainer

# Panel compacto que muestra un jugador del ranking al tocar su fila.
# No hace requests: usa los datos ya cargados en la fila.


signal cerrado


@onready var _avatar_badge: LeaderboardAvatarBadge = $Margin/VBox/Header/AvatarBadge
@onready var _label_nombre: Label = %NombreLabel
@onready var _label_posicion: Label = %DetalleLabel
@onready var _label_puntaje: Label = %PuntajeLabel
@onready var _badge_propia: PanelContainer = %BadgePropia
@onready var _boton_cerrar: Button = %BotonCerrar


func _ready() -> void:
	if is_instance_valid(_boton_cerrar):
		_boton_cerrar.pressed.connect(func() -> void: cerrado.emit())


func mostrar(entrada: Dictionary, scope: String, es_propio: bool) -> void:
	var posicion: int = int(entrada.get("rank", 0))
	var puntaje: int = int(entrada.get("score", 0))
	var nombre := LeaderboardFormat.resolver_nombre_entrada(entrada)

	if is_instance_valid(_avatar_badge):
		_avatar_badge.mostrar_para_entrada(entrada, es_propio)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = nombre
		if es_propio:
			_label_nombre.add_theme_color_override(
				"font_color",
				Color(0.22, 0.38, 0.30, 1)
			)
		else:
			_label_nombre.remove_theme_color_override("font_color")
	if is_instance_valid(_badge_propia):
		_badge_propia.visible = es_propio
	if is_instance_valid(_label_posicion):
		_label_posicion.text = LeaderboardFormat.texto_posicion(posicion)
		_label_posicion.add_theme_color_override(
			"font_color",
			LeaderboardFormat.color_posicion_tarjeta_clara(posicion)
		)
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = LeaderboardFormat.formatear_score(puntaje, scope)
		if es_propio:
			_label_puntaje.add_theme_color_override(
				"font_color",
				Color(0.25882354, 0.47058824, 0.36862746, 1)
			)
		else:
			_label_puntaje.remove_theme_color_override("font_color")

