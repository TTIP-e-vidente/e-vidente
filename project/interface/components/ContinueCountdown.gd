extends Control
class_name ContinueCountdown

signal continuar_solicitado

const DURACION_FADE_IN := 0.18
const DURACION_TEXTURA := 0.70
const TEXTURAS_FLECHA: Array[Texture2D] = [
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-1.png"),
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-2.png"),
	preload("res://assets-sistema/interfaz/flecha-ir-para-adelante-desbloqueada-historias-3.png"),
]

@onready var arrow_button: TextureButton = $VBoxContainer/ArrowButton
@onready var countdown_label: Label = $VBoxContainer/CountdownLabel
@onready var timer: Timer = $Timer

var segundos_restantes: int = 5
var ya_emitio: bool = false
var _arrow_color_tween: Tween = null
var _textura_idx: int = 0


func _ready() -> void:
	arrow_button.pressed.connect(_emitir_continuar)
	timer.timeout.connect(_on_timer_timeout)
	ocultar()


func iniciar(segundos: int = 5) -> void:
	segundos_restantes = max(1, segundos)
	ya_emitio = false
	show()
	move_to_front()
	_actualizar_texto()
	_animar_entrada()
	_start_continue_arrow_color_cycle()
	timer.stop()
	timer.start()


func detener() -> void:
	timer.stop()
	_stop_continue_arrow_color_cycle()


func ocultar() -> void:
	detener()
	hide()


func _actualizar_texto() -> void:
	countdown_label.text = "Pasar al siguiente capítulo en %ds..." % segundos_restantes


func _emitir_continuar() -> void:
	if ya_emitio:
		return
	ya_emitio = true
	detener()
	continuar_solicitado.emit()


func _start_continue_arrow_color_cycle() -> void:
	_stop_continue_arrow_color_cycle()
	_textura_idx = 0
	arrow_button.texture_normal = TEXTURAS_FLECHA[0]
	_arrow_color_tween = create_tween().set_loops()
	for i_tex in TEXTURAS_FLECHA.size():
		_arrow_color_tween.tween_interval(DURACION_TEXTURA)
		_arrow_color_tween.tween_callback(_siguiente_textura)


func _siguiente_textura() -> void:
	_textura_idx = (_textura_idx + 1) % TEXTURAS_FLECHA.size()
	arrow_button.texture_normal = TEXTURAS_FLECHA[_textura_idx]


func _stop_continue_arrow_color_cycle() -> void:
	if _arrow_color_tween != null and _arrow_color_tween.is_valid():
		_arrow_color_tween.kill()
	_arrow_color_tween = null
	if is_instance_valid(arrow_button):
		arrow_button.texture_normal = TEXTURAS_FLECHA[0]


func _animar_entrada() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, DURACION_FADE_IN)


func _on_timer_timeout() -> void:
	if ya_emitio:
		timer.stop()
		return

	segundos_restantes -= 1
	if segundos_restantes <= 0:
		_emitir_continuar()
		return

	_actualizar_texto()