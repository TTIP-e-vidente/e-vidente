extends VBoxContainer

# Estado vacío del leaderboard con mensaje según si hay sesión o no.


signal iniciar_sesion_solicitado


const RUBIK_FONT_PATH := "res://fonts/Rubik-VariableFont_wght.ttf"


@onready var _label_titulo: Label = $Titulo
@onready var _label_mensaje: Label = $Mensaje
@onready var _boton_iniciar_sesion: Button = $BotonIniciarSesion


func _ready() -> void:
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false
		_boton_iniciar_sesion.pressed.connect(func() -> void: iniciar_sesion_solicitado.emit())
		_aplicar_estilo_boton()


func configurar_para_jugador(es_invitado: bool) -> void:
	if not is_instance_valid(_label_titulo) or not is_instance_valid(_label_mensaje):
		return

	if es_invitado:
		_label_titulo.text = "Ranking global disponible"
		_label_mensaje.text = (
			"Iniciá sesión para ver tu posición y competir con otros jugadores."
		)
	else:
		_label_titulo.text = "Todavía no hay datos"
		_label_mensaje.text = "Jugá una partida para aparecer en el ranking."

	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = es_invitado


func _aplicar_estilo_boton() -> void:
	var rubik: Font = load(RUBIK_FONT_PATH) as Font
	var btn := StyleBoxFlat.new()
	btn.bg_color = MiPaleta.VERDE_BOSQUE
	btn.set_corner_radius_all(10)
	btn.content_margin_left = 16
	btn.content_margin_right = 16
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	_boton_iniciar_sesion.add_theme_stylebox_override("normal", btn)
	_boton_iniciar_sesion.add_theme_stylebox_override("hover", btn)
	_boton_iniciar_sesion.add_theme_color_override("font_color", Color.WHITE)
	if rubik != null:
		_boton_iniciar_sesion.add_theme_font_override("font", rubik)
