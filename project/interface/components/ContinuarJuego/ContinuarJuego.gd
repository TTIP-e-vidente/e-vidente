extends Control

signal continuar_solicitado

const SEGUNDOS_PREDETERMINADOS := 5
const TOOLTIP_SIGUIENTE_JUEGO := "Siguiente modalidad"
const TOOLTIP_FINALIZAR := "Volver al mapa"
const TOOLTIP_CONTINUAR_PENDIENTE := "Continuar partida"

@export var textura_flecha: Texture2D

@onready var _flecha_continuar: Button = $ColumnaContinuacion/FlechaContinuar
@onready var _timer_continuacion: Timer = $TimerContinuacion

var _segundos_restantes := SEGUNDOS_PREDETERMINADOS
var _tooltip_accion := TOOLTIP_SIGUIENTE_JUEGO
var ya_solicito_continuar := false


func _ready() -> void:
	_aplicar_textura_flecha()
	_flecha_continuar.pressed.connect(_al_presionar_flecha)
	_timer_continuacion.timeout.connect(_al_terminar_segundo)
	ocultar()


func mostrar_para_siguiente_juego(segundos: int = SEGUNDOS_PREDETERMINADOS) -> void:
	_mostrar(TOOLTIP_SIGUIENTE_JUEGO, segundos)


func mostrar_para_finalizar(segundos: int = SEGUNDOS_PREDETERMINADOS) -> void:
	_mostrar(TOOLTIP_FINALIZAR, segundos)


func mostrar_para_continuar_pendiente() -> void:
	_mostrar_sin_temporizador(TOOLTIP_CONTINUAR_PENDIENTE)


func ocultar() -> void:
	_timer_continuacion.stop()
	hide()


func _mostrar(tooltip_accion: String, segundos: int) -> void:
	_tooltip_accion = tooltip_accion.strip_edges()
	_segundos_restantes = max(1, segundos)
	ya_solicito_continuar = false
	_flecha_continuar.disabled = false
	_flecha_continuar.tooltip_text = _tooltip_accion
	show()
	move_to_front()
	_timer_continuacion.start()
	_flecha_continuar.grab_focus()


func _mostrar_sin_temporizador(tooltip_accion: String) -> void:
	_tooltip_accion = tooltip_accion.strip_edges()
	ya_solicito_continuar = false
	_timer_continuacion.stop()
	_flecha_continuar.disabled = false
	_flecha_continuar.tooltip_text = _tooltip_accion
	show()
	move_to_front()


func _aplicar_textura_flecha() -> void:
	if textura_flecha != null:
		_flecha_continuar.icon = textura_flecha


func _al_presionar_flecha() -> void:
	_emitir_continuar_una_sola_vez()


func _al_terminar_segundo() -> void:
	_segundos_restantes -= 1
	if _segundos_restantes <= 0:
		_emitir_continuar_una_sola_vez()
		return


func _emitir_continuar_una_sola_vez() -> void:
	if ya_solicito_continuar:
		return
	ya_solicito_continuar = true
	_timer_continuacion.stop()
	_flecha_continuar.disabled = true
	continuar_solicitado.emit()
