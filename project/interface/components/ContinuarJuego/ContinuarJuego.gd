extends Control

signal continuar_solicitado

const SEGUNDOS_PREDETERMINADOS := 5
const TOOLTIP_SIGUIENTE_JUEGO := "Siguiente modalidad"
const TOOLTIP_FINALIZAR := "Volver al mapa"
const TOOLTIP_CONTINUAR_PENDIENTE := "Continuar partida"
const TEXTURA_FLECHA_PREDETERMINADA := preload(
	"res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-3.png"
)
const TEXTURAS_FLECHA_ANIMADA := [
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-1.png"),
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-2.png"),
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-3.png"),
]

@export var textura_flecha: Texture2D

@onready var _flecha_continuar: Button = $ColumnaContinuacion/FlechaContinuar
@onready var _timer_continuacion: Timer = $TimerContinuacion

var _segundos_restantes := SEGUNDOS_PREDETERMINADOS
var _tooltip_accion := TOOLTIP_SIGUIENTE_JUEGO
var ya_solicito_continuar := false
var _animacion_flecha: Tween = null


func _ready() -> void:
	z_as_relative = false
	z_index = 200
	_aplicar_textura_flecha()
	_aplicar_colores_de_icono()
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
	_detener_animacion_flecha()
	hide()


func _mostrar(tooltip_accion: String, segundos: int) -> void:
	_tooltip_accion = tooltip_accion.strip_edges()
	_segundos_restantes = max(1, segundos)
	ya_solicito_continuar = false
	_flecha_continuar.disabled = false
	_flecha_continuar.tooltip_text = ""
	show()
	move_to_front()
	_iniciar_animacion_flecha()
	_timer_continuacion.start()
	_flecha_continuar.grab_focus()


func _mostrar_sin_temporizador(tooltip_accion: String) -> void:
	_tooltip_accion = tooltip_accion.strip_edges()
	ya_solicito_continuar = false
	_timer_continuacion.stop()
	_flecha_continuar.disabled = false
	_flecha_continuar.tooltip_text = ""
	show()
	move_to_front()
	_iniciar_animacion_flecha()


func _aplicar_textura_flecha() -> void:
	if textura_flecha != null:
		_flecha_continuar.icon = textura_flecha
	else:
		_flecha_continuar.icon = TEXTURA_FLECHA_PREDETERMINADA
	_flecha_continuar.modulate = Color.WHITE


func _aplicar_colores_de_icono() -> void:
	for color_name in [
		"icon_normal_color",
		"icon_hover_color",
		"icon_pressed_color",
		"icon_hover_pressed_color",
		"icon_focus_color",
		"icon_disabled_color",
	]:
		_flecha_continuar.add_theme_color_override(color_name, Color.WHITE)


func _iniciar_animacion_flecha() -> void:
	_detener_animacion_flecha()
	_animacion_flecha = create_tween().set_loops()
	for textura in TEXTURAS_FLECHA_ANIMADA:
		_animacion_flecha.tween_callback(_aplicar_icono_animado.bind(textura))
		_animacion_flecha.tween_interval(0.4)


func _detener_animacion_flecha() -> void:
	if _animacion_flecha != null:
		_animacion_flecha.kill()
		_animacion_flecha = null
	_aplicar_textura_flecha()


func _aplicar_icono_animado(textura: Texture2D) -> void:
	if is_instance_valid(_flecha_continuar):
		_flecha_continuar.icon = textura


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
