extends Control

signal flow_completed

const DayCircleScript := preload("res://interface/components/DayCircle.gd")
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)
const ContextoSesionDeJuegoScript := preload("res://niveles/progress/ContextoSesionDeJuego.gd")

const DEFAULT_RETURN_TO := "res://mapas/MapScene.tscn"
const STREAK_FEEDBACK_META := "streak_feedback"
const STREAK_CONTINUE_TARGET_META := "streak_continue_target"

@export var empty_message := "Completa una actividad para empezar la racha."
@export var feedback_default_message := "Hoy mantuviste la racha."
@export var week_messages: PackedStringArray = PackedStringArray()

var _current_count: int = 0
var _best_count: int = 0
var _status_detail: String = ""
var _streak_state := "inactive"
var _feedback_continue_target: Dictionary = {}

@onready var map_hud: CanvasLayer = $StreakView/MapHud
@onready var streak_count_label: Label = $StreakView/nroRacha
@onready var back_button: Button = $StreakView/MapHud/HudRoot/BackAnchor/BackButton
@onready var _detail_label: Label = $StreakView/EstadoRacha
@onready var _continue_button: Button = $StreakView/ContinueButton
@onready var _day_circles: Array[TextureRect] = [
	$StreakView/HBoxContainer/DayCircle/TextureRect,
	$StreakView/HBoxContainer/DayCircle2/TextureRect,
	$StreakView/HBoxContainer/DayCircle3/TextureRect,
	$StreakView/HBoxContainer/DayCircle4/TextureRect,
	$StreakView/HBoxContainer/DayCircle5/TextureRect,
	$StreakView/HBoxContainer/DayCircle6/TextureRect,
	$StreakView/HBoxContainer/DayCircle7/TextureRect,
]
@onready var _connector_sprites: Array[Sprite2D] = [
	$StreakView/HBoxContainer/lunYMar,
	$StreakView/HBoxContainer/lunAMier,
	$StreakView/HBoxContainer/lunAJue,
	$StreakView/HBoxContainer/lunAVie,
	$StreakView/HBoxContainer/lunASab,
	$StreakView/HBoxContainer/lunADom,
]


func _ready() -> void:
	_conectar_boton_continuar()
	_conectar_hud_mapa()
	_cargar_estado_entrada()
	

func _cargar_estado_entrada() -> void:
	var feedback: Dictionary = _leer_y_limpiar_meta_raiz(STREAK_FEEDBACK_META)
	_feedback_continue_target = _leer_y_limpiar_meta_raiz(STREAK_CONTINUE_TARGET_META)
	if feedback.is_empty():
		renderizar()
		return
	_mostrar_feedback(feedback)


func renderizar(streak_modelo_vista: Dictionary = {}) -> void:
	_establecer_modo_regular()
	var resolved_modelo_vista: Dictionary = _resolver_modelo_vista_racha(streak_modelo_vista)
	_current_count = max(0, int(resolved_modelo_vista.get("current_count", 0)))
	_best_count = max(_current_count, int(resolved_modelo_vista.get("best_count", 0)))
	_status_detail = _resolver_detalle_estado_regular(resolved_modelo_vista)
	_streak_state = str(
	resolved_modelo_vista.get("streak_state", "inactive"))
	_refrescar_ui()


func _mostrar_feedback(feedback: Dictionary) -> void:
	_establecer_modo_feedback()
	var base_modelo_vista: Dictionary = _resolver_modelo_vista_racha({})

	var base_current_count: int = max(
		0,
		int(base_modelo_vista.get("current_count", 0))
	)
	var base_best_count: int = max(
		base_current_count,
		int(base_modelo_vista.get("best_count", 0))
	)

	_current_count = maxi(
		base_current_count,
		int(feedback.get("current_count", base_current_count))
	)
	_best_count = maxi(
		maxi(_current_count, base_best_count),
		int(feedback.get("best_count", base_best_count))
	)

	_status_detail = _construir_mensaje_racha(_current_count)
	if _status_detail.is_empty():
		_status_detail = str(feedback.get("message", feedback_default_message)).strip_edges()

	# Feedback post-partida implica actividad registrada hoy: no mostrar badge en warning.
	_streak_state = "active"
	_refrescar_ui()
	_refrescar_insignia_racha_mapa()


func _establecer_modo_regular() -> void:
	_feedback_continue_target = {}
	_continue_button.visible = false
	_continue_button.disabled = true
	if back_button != null:
		back_button.visible = true


func _establecer_modo_feedback() -> void:
	_continue_button.visible = true
	_continue_button.disabled = false
	if back_button != null:
		back_button.visible = false


func _resolver_modelo_vista_racha(streak_modelo_vista: Dictionary) -> Dictionary:
	if not streak_modelo_vista.is_empty():
		return streak_modelo_vista

	var global_node: Node = ContextoSesionDeJuegoScript.obtener_global()
	if global_node == null or not global_node.has_method("obtener_modelo_vista_racha"):
		return {}

	var raw_modelo_vista: Variant = global_node.call("obtener_modelo_vista_racha")
	if raw_modelo_vista is Dictionary:
		return raw_modelo_vista
	return {}


func _resolver_detalle_estado_regular(streak_modelo_vista: Dictionary) -> String:
	if _current_count > 0:
		return _construir_mensaje_racha(_current_count)
	return str(streak_modelo_vista.get("status_detail", "")).strip_edges()


func _refrescar_insignia_racha_mapa() -> void:
	if map_hud == null:
		return
	var racha_control: Control = map_hud.get_node_or_null("HudRoot/RachaAnchor/Racha") as Control
	if racha_control == null or not racha_control.has_method("renderizar"):
		return
	racha_control.call(
		"renderizar",
		{
			"current_count": _current_count,
			"best_count": _best_count,
			"streak_state": _streak_state,
		}
	)


func _refrescar_ui() -> void:

	if not is_node_ready():
		return
	streak_count_label.text = str(_current_count)
	_detail_label.text = _resolver_texto_detalle()
	var visible_day_count: int = _resolver_cantidad_dias_visibles()

	for connector_index in range(_connector_sprites.size()):
		var connector_sprite: Sprite2D = _connector_sprites[connector_index]
		if connector_sprite == null:
			continue
		connector_sprite.visible = (
			visible_day_count >= 2
			and connector_index == visible_day_count - 2
		)

	for day_index in range(_day_circles.size()):
		var day_circle: TextureRect = _day_circles[day_index]
		if day_circle == null:
			continue

		var slot: Control = day_circle.get_parent() as Control
		if slot != null:
			slot.visible = true

		var should_show_day: bool = day_index < visible_day_count
		day_circle.visible = should_show_day
		if not should_show_day:
			continue

		day_circle.call("set_estado", DayCircleScript.Estado.COMPLETO)




func _resolver_texto_detalle() -> String:
	if _streak_state == "warning":
		return "Jugá hoy para mantener la racha"
		
	if not _status_detail.is_empty():
		return _status_detail

	if _streak_state == "inactive":
		return "Tu racha se reinicio"

	if _best_count > 0:
		return "Mejor racha: %d dias" % _best_count
	return empty_message


func _resolver_cantidad_dias_visibles() -> int:
	var cycle_days: int = _resolver_dias_ciclo()
	if _current_count <= 0 or cycle_days <= 0:
		return 0

	var visible_day_count: int = _current_count % cycle_days
	if visible_day_count == 0:
		return cycle_days
	return visible_day_count


func _resolver_dias_ciclo() -> int:
	var cycle_days: int = _day_circles.size()
	if cycle_days > 0:
		return cycle_days
	return week_messages.size()


func _conectar_boton_continuar() -> void:
	if not _continue_button.pressed.is_connected(_on_boton_continuar_presionado):
		_continue_button.pressed.connect(_on_boton_continuar_presionado)


func _conectar_hud_mapa() -> void:
	if map_hud == null or not map_hud.has_signal("back_requested"):
		return
	var callback := Callable(self, "_on_volver_solicitado")
	if not map_hud.is_connected("back_requested", callback):
		map_hud.connect("back_requested", callback)


func _construir_mensaje_racha(count: int) -> String:
	if count <= 0:
		return ""

	var day_in_week: int = ((count - 1) % 7) + 1
	var week_number: int = floori(float(count - 1) / 7.0) + 1

	var message: String = ""
	if week_number <= 1:
		match day_in_week:
			1:
				message = "Muy bien. Este camino ya empezo."
			2:
				message = "Volviste, y eso ya empieza a tomar forma."
			3:
				message = "Tres dias seguidos. Tu constancia ya se nota."
			4:
				message = "La racha se viene sosteniendo de verdad."
			5:
				message = "Ya falta poco para cerrar la semana."
			6:
				message = "Estas a un paso de completar la semana."
			7:
				message = "Semana completa. Frena un segundo y celebralo."
			_:
				message = "Seguis sumando, y eso ya dice mucho."
		return message

	match day_in_week:
		1:
			message = "Empezo otra semana y la racha sigue."
		2:
			message = "La racha sigue firme. Ya van %d dias seguidos." % count
		3:
			message = "La constancia ya se nota."
		4:
			message = "Otra semana en marcha. La racha se sostiene."
		5:
			message = "Ya falta poco para cerrar otra semana."
		6:
			message = "Falta un paso para completar otra semana."
		7:
			message = "Otra semana completa. Tu racha sigue creciendo."
		_:
			message = "Seguis sumando, y eso ya dice mucho."
	return message


func _leer_y_limpiar_meta_raiz(meta_key: String) -> Dictionary:
	if get_tree() == null or get_tree().root == null:
		return {}
	var tree_root: Window = get_tree().root
	if not tree_root.has_meta(meta_key):
		return {}
	var raw_meta: Variant = tree_root.get_meta(meta_key, {})
	tree_root.remove_meta(meta_key)
	if raw_meta is Dictionary:
		return (raw_meta as Dictionary).duplicate(true)
	return {}


func _on_boton_continuar_presionado() -> void:
	flow_completed.emit()
	_finalizar_flujo_racha()


func _finalizar_flujo_racha() -> void:
	PostGameFlowControllerScript.navegar_despues_racha(
		get_tree(),
		_consumir_return_to_de_racha()
		
	)


func _on_volver_solicitado() -> void:
	_volver_desde_racha()


func _volver_desde_racha() -> void:
	PostGameFlowControllerScript.navigate_to_return_target(
		get_tree(),
		_consumir_return_to_de_racha()
	)


func _consumir_return_to_de_racha() -> String:
	return GameSceneRouter.consumir_retorno_racha(
		get_tree(),
		DEFAULT_RETURN_TO
	)
