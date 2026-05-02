extends Control
class_name ContinueCountdown

signal continuar_solicitado

@onready var flecha_boton: Button = $CenterContainer/Content/FlechaButton
@onready var contador_label: Label = $CenterContainer/Content/ContadorLabel
@onready var timer: Timer = $Timer

const ESCALA_PULSO := Vector2(1.06, 1.06)
const DURACION_PULSO := 0.45
const DURACION_FADE_IN := 0.18
const DURACION_TICK_TEXTO := 0.18

var segundos_restantes: int = 5
var ya_emitio: bool = false
var tween_pulso: Tween = null


func _ready() -> void:
	flecha_boton.pressed.connect(_emitir_continuar)
	timer.timeout.connect(_on_timer_timeout)
	_preparar_pivotes_animacion()
	ocultar()


func iniciar(segundos: int = 5) -> void:
	segundos_restantes = max(1, segundos)
	ya_emitio = false
	show()
	_preparar_pivotes_animacion()
	move_to_front()
	_actualizar_texto()
	_animar_entrada()
	_animar_flecha()
	timer.stop()
	timer.start()


func detener() -> void:
	timer.stop()
	if tween_pulso != null and tween_pulso.is_valid():
		tween_pulso.kill()
	tween_pulso = null


func ocultar() -> void:
	detener()
	hide()


func _actualizar_texto() -> void:
	contador_label.text = "Próximo juego en %ds..." % segundos_restantes


func _preparar_pivotes_animacion() -> void:
	flecha_boton.pivot_offset = flecha_boton.size * 0.5
	contador_label.pivot_offset = contador_label.size * 0.5


func _emitir_continuar() -> void:
	if ya_emitio:
		return

	ya_emitio = true
	detener()
	continuar_solicitado.emit()


func _animar_flecha() -> void:
	if tween_pulso != null and tween_pulso.is_valid():
		tween_pulso.kill()
	flecha_boton.scale = Vector2.ONE
	tween_pulso = create_tween().set_loops()
	tween_pulso.tween_property(flecha_boton, "scale", ESCALA_PULSO, DURACION_PULSO)
	tween_pulso.tween_property(flecha_boton, "scale", Vector2.ONE, DURACION_PULSO)


func _animar_entrada() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, DURACION_FADE_IN)


func _animar_texto() -> void:
	contador_label.scale = Vector2(1.08, 1.08)
	var tween := create_tween()
	tween.tween_property(contador_label, "scale", Vector2.ONE, DURACION_TICK_TEXTO)


func _on_timer_timeout() -> void:
	if ya_emitio:
		timer.stop()
		return

	segundos_restantes -= 1
	if segundos_restantes <= 0:
		_emitir_continuar()
		return

	_actualizar_texto()
	_animar_texto()
