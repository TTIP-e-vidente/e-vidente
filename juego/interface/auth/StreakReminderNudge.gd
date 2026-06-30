extends CanvasLayer

signal accion_solicitada(accion: int)

const HelperScript := preload("res://interface/auth/StreakReminderHelper.gd")

const COLOR_TITULO_BASE := Color(0.72, 0.16, 0.12, 1)
const COLOR_CUERPO_BASE := Color(0.45, 0.2, 0.16, 1)
const COLOR_HINT_BASE := Color(0.55, 0.35, 0.3, 0.85)
const COLOR_TEXTO_OK := Color(0.18, 0.34, 0.26, 1)
const COLOR_TEXTO_ERROR := Color(0.82, 0.22, 0.18, 1)
const DURACION_AVISO_ERROR := 4.0

@onready var _icon_panel: PanelContainer = (
	$PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/IconPanel
)
@onready var _titulo: Label = (
	$PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/ContentColumn/TituloLabel
)
@onready var _cuerpo: Label = (
	$PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/ContentColumn/CuerpoLabel
)
@onready var _hint: Label = (
	$PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/ContentColumn/HintLabel
)
@onready var _boton: Button = (
	$PopupAnchor/PanelContainer/MarginContainer/HBoxContainer/ContentColumn/BotonAccion
)

var _accion_actual: int = HelperScript.AccionNudge.NINGUNA
var _mensaje_temporal: String = ""
var _mensaje_es_ok: bool = false
var _procesando := false
var _texto_boton_original := ""
var _timer_ocultar: SceneTreeTimer = null


func _ready() -> void:
	_texto_boton_original = _boton.text
	_boton.pressed.connect(_al_presionar_boton)
	visible = false


func set_procesando(activo: bool) -> void:
	_procesando = activo
	if is_instance_valid(_boton):
		_boton.disabled = activo
		_boton.text = "Activando..." if activo else _texto_boton_resuelto()


func ocultar() -> void:
	_cancelar_timer_ocultar()
	_mensaje_temporal = ""
	_mensaje_es_ok = false
	_procesando = false
	_accion_actual = HelperScript.AccionNudge.NINGUNA
	if is_instance_valid(_boton):
		_boton.disabled = false
	visible = false


func mostrar_aviso(texto: String, es_ok: bool = false) -> void:
	if es_ok:
		ocultar()
		return
	_mensaje_temporal = texto.strip_edges()
	_mensaje_es_ok = es_ok
	refrescar()


func refrescar() -> void:
	if _procesando:
		visible = true
		return

	var datos: Dictionary = HelperScript.resolver_nudge()
	if not bool(datos.get("visible", false)):
		if _mensaje_temporal.is_empty():
			ocultar()
			return
		_mostrar_solo_mensaje_temporal()
		_programar_ocultar_si_error()
		return

	_cancelar_timer_ocultar()
	_mensaje_temporal = ""
	_accion_actual = int(datos.get("accion", HelperScript.AccionNudge.NINGUNA))
	_icon_panel.visible = true
	_titulo.visible = true
	_titulo.text = str(datos.get("titulo", "Racha en riesgo"))
	_aplicar_color_label(_titulo, COLOR_TITULO_BASE)
	_cuerpo.text = str(datos.get("cuerpo", datos.get("mensaje", "")))
	_aplicar_color_label(_cuerpo, COLOR_CUERPO_BASE)
	var hint := str(datos.get("hint", "")).strip_edges()
	_hint.text = hint
	_hint.visible = not hint.is_empty()
	_aplicar_color_label(_hint, COLOR_HINT_BASE)
	_texto_boton_original = str(datos.get("boton", "Continuar"))
	_boton.text = _texto_boton_resuelto()
	_boton.disabled = false
	_boton.visible = _accion_actual != HelperScript.AccionNudge.NINGUNA
	visible = true


func _mostrar_solo_mensaje_temporal() -> void:
	_accion_actual = HelperScript.AccionNudge.NINGUNA
	_icon_panel.visible = false
	_titulo.visible = false
	_hint.visible = false
	_cuerpo.text = _mensaje_temporal
	_aplicar_color_label(_cuerpo, COLOR_TEXTO_OK if _mensaje_es_ok else COLOR_TEXTO_ERROR)
	_boton.visible = false
	_boton.disabled = false
	visible = true


func _programar_ocultar_si_error() -> void:
	if _mensaje_es_ok or _mensaje_temporal.is_empty():
		return
	_cancelar_timer_ocultar()
	_timer_ocultar = get_tree().create_timer(DURACION_AVISO_ERROR)
	_timer_ocultar.timeout.connect(_on_timer_ocultar_error)


func _on_timer_ocultar_error() -> void:
	_timer_ocultar = null
	if _mensaje_es_ok or _procesando:
		return
	ocultar()


func _cancelar_timer_ocultar() -> void:
	if _timer_ocultar == null:
		return
	if _timer_ocultar.timeout.is_connected(_on_timer_ocultar_error):
		_timer_ocultar.timeout.disconnect(_on_timer_ocultar_error)
	_timer_ocultar = null


func _texto_boton_resuelto() -> String:
	if _texto_boton_original.is_empty():
		return "Continuar"
	return _texto_boton_original


func _al_presionar_boton() -> void:
	if _procesando:
		return
	if _accion_actual != HelperScript.AccionNudge.NINGUNA:
		accion_solicitada.emit(_accion_actual)


func _aplicar_color_label(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.modulate = Color.WHITE
