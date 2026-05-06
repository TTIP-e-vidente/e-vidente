extends Control

signal continuar_solicitado

const SEGUNDOS_PREDETERMINADOS := 5
const TEXTO_SIGUIENTE_JUEGO := "se pasara"
const TEXTO_FINALIZAR := "se pasara"

@onready var _boton_continuar: Button = $ColumnaContinuacion/BotonContinuar
@onready var _label_contador: Label = $ColumnaContinuacion/ContadorMarco/ContadorPadding/LabelContador
@onready var _timer_continuacion: Timer = $TimerContinuacion

var _segundos_restantes := SEGUNDOS_PREDETERMINADOS
var _texto_accion := TEXTO_SIGUIENTE_JUEGO
var ya_solicito_continuar := false


func _ready() -> void:
	_boton_continuar.pressed.connect(_al_presionar_boton)
	_timer_continuacion.timeout.connect(_al_terminar_segundo)
	ocultar()


func mostrar_para_siguiente_juego(segundos: int = SEGUNDOS_PREDETERMINADOS) -> void:
	_mostrar(TEXTO_SIGUIENTE_JUEGO, segundos)


func mostrar_para_finalizar(segundos: int = SEGUNDOS_PREDETERMINADOS) -> void:
	_mostrar(TEXTO_FINALIZAR, segundos)


func ocultar() -> void:
	_timer_continuacion.stop()
	hide()


func _mostrar(texto_accion: String, segundos: int) -> void:
	_texto_accion = texto_accion.strip_edges()
	_segundos_restantes = max(1, segundos)
	ya_solicito_continuar = false
	_boton_continuar.disabled = false
	show()
	move_to_front()
	_actualizar_contador()
	_timer_continuacion.start()
	_boton_continuar.grab_focus()


func _actualizar_contador() -> void:
	_label_contador.text = "En %d... %s" % [_segundos_restantes, _texto_accion]


func _al_presionar_boton() -> void:
	_emitir_continuar_una_sola_vez()


func _al_terminar_segundo() -> void:
	_segundos_restantes -= 1
	if _segundos_restantes <= 0:
		_emitir_continuar_una_sola_vez()
		return
	_actualizar_contador()


func _emitir_continuar_una_sola_vez() -> void:
	if ya_solicito_continuar:
		return
	ya_solicito_continuar = true
	_timer_continuacion.stop()
	_boton_continuar.disabled = true
	continuar_solicitado.emit()
