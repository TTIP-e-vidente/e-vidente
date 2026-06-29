# Anillo + etiqueta para marcar la lección disponible actual en el mapa.
extends Node2D
class_name IndicadorLeccionSiguiente

const RADIO_BASE := 78.0
const GROSOR_ANILLO := 3.0
const COLOR_ANILLO := Color("#7fff3a")  # Verde-lima brillante, igual que el ícono desbloqueado

var _pulso_tween: Tween = null
var _radio_anillo: float = RADIO_BASE


func _ready() -> void:
	visible = false
	z_index = -1
	set_process(false)


func establecer_activo(
	activo: bool,
	numero_leccion: int,
	titulo: String = "",
	radio_anillo: float = RADIO_BASE
) -> void:
	_radio_anillo = maxf(24.0, radio_anillo)
	visible = activo and not Engine.is_editor_hint()
	var label := get_node_or_null("Label") as Label
	if not visible:
		if label != null:
			label.visible = false
		_detener_pulso()
		queue_redraw()
		return

	if label != null:
		var numero := maxi(1, numero_leccion)
		var titulo_limpio := titulo.strip_edges()
		if (
			titulo_limpio.is_empty()
			or titulo_limpio.begins_with("Nodo ")
			or titulo_limpio.begins_with("Receta ")
			or titulo_limpio.begins_with("Pregunta ")
		):
			label.text = "Lección %d" % numero
		else:
			label.text = titulo_limpio
		label.visible = true

	_iniciar_pulso()
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var alpha := clampf(modulate.a, 0.45, 1.0)
	var color := Color(COLOR_ANILLO.r, COLOR_ANILLO.g, COLOR_ANILLO.b, alpha)
	draw_arc(Vector2.ZERO, _radio_anillo, 0.0, TAU, 96, color, GROSOR_ANILLO, true)


func _iniciar_pulso() -> void:
	_detener_pulso()
	modulate = Color.WHITE
	_pulso_tween = create_tween().set_loops()
	_pulso_tween.set_trans(Tween.TRANS_SINE)
	_pulso_tween.set_ease(Tween.EASE_IN_OUT)
	# Pulso más drámático: baja hasta 0.4 de alpha para resaltar bien
	_pulso_tween.tween_property(self, "modulate:a", 0.4, 0.6)
	_pulso_tween.tween_property(self, "modulate:a", 1.0, 0.6)


func _detener_pulso() -> void:
	if _pulso_tween != null:
		_pulso_tween.kill()
	_pulso_tween = null
	modulate = Color.WHITE
