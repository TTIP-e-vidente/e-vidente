class_name LeaderboardEntryPeek
extends PanelContainer

# Panel compacto que muestra un jugador del ranking al tocar su fila.
# No hace requests: usa los datos ya cargados en la fila.


const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"


signal cerrado


@onready var _avatar_badge: LeaderboardAvatarBadge = $Margin/VBox/Header/AvatarBadge
@onready var _label_nombre: Label = $Margin/VBox/Header/NombreLabel
@onready var _label_posicion: Label = $Margin/VBox/DetalleLabel
@onready var _label_puntaje: Label = $Margin/VBox/PuntajeLabel
@onready var _boton_cerrar: Button = $Margin/VBox/BotonCerrar


func _ready() -> void:
	_aplicar_fuente()
	if is_instance_valid(_boton_cerrar):
		_boton_cerrar.pressed.connect(func() -> void: cerrado.emit())


func _aplicar_fuente() -> void:
	var rubik: Font = load(RUBIK_FONT_PATH) as Font
	if rubik == null:
		return
	for nodo: Node in [_label_nombre, _label_posicion, _label_puntaje, _boton_cerrar]:
		if is_instance_valid(nodo):
			(nodo as Control).add_theme_font_override("font", rubik)


func mostrar(entrada: Dictionary, scope: String, es_propio: bool) -> void:
	var posicion: int = int(entrada.get("rank", 0))
	var puntaje: int = int(entrada.get("score", 0))
	var nombre := _resolver_nombre(entrada)

	if is_instance_valid(_avatar_badge):
		_avatar_badge.mostrar_para_entrada(entrada, es_propio)
	if is_instance_valid(_label_nombre):
		_label_nombre.text = nombre
	if is_instance_valid(_label_posicion):
		_label_posicion.text = "Puesto %s" % LeaderboardFormat.texto_posicion(posicion)
	if is_instance_valid(_label_puntaje):
		_label_puntaje.text = LeaderboardFormat.formatear_score(puntaje, scope)


func _resolver_nombre(entrada: Dictionary) -> String:
	var display: Variant = entrada.get("display_name", null)
	if display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = entrada.get("username", "")
	return username as String if username is String else "Jugador"
