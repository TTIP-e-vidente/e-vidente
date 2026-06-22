extends VBoxContainer

# Estado vacío del leaderboard con mensaje según si hay sesión o no.


signal iniciar_sesion_solicitado


@onready var _label_titulo: Label = $Titulo
@onready var _label_mensaje: Label = $Mensaje
@onready var _boton_iniciar_sesion: Button = $BotonIniciarSesion


func _ready() -> void:
	if is_instance_valid(_boton_iniciar_sesion):
		_boton_iniciar_sesion.visible = false
		_boton_iniciar_sesion.pressed.connect(func() -> void: iniciar_sesion_solicitado.emit())


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
