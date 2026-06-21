class_name ProgresoPuestoCard
extends PanelContainer

# Tarjeta de progreso competitivo del jugador (UNQ-173).
#
# Muestra:
#   - El puesto actual del jugador en el ranking global.
#   - Su EXP acumulada.
#   - El nombre del jugador que está un puesto por encima (el rival a superar).
#   - La EXP que necesita ganar para superarlo.
#   - Una barra de progreso visual entre 0% y 99% (100% solo si es primero).
#
# Uso:
#   card.cargar_y_mostrar()           → pide al API y muestra
#   card.mostrar_desde_datos(datos)   → si ya tenés el diccionario del API


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _label_puesto:    Label       = $MarginContainer/VBox/FilaSuperior/LabelPuesto
@onready var _label_exp:       Label       = $MarginContainer/VBox/FilaSuperior/LabelExp
@onready var _label_meta:      Label       = $MarginContainer/VBox/FilaInferior/LabelMeta
@onready var _barra_progreso:  ProgressBar = $MarginContainer/VBox/BarraProgreso
@onready var _contenedor_carga: Control    = $Cargando
@onready var _contenedor_datos: Control    = $MarginContainer


# ── Estado interno ─────────────────────────────────────────────────────────────

var _cargando: bool = false


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_contenedor_datos.visible = false
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false


# ── API pública ────────────────────────────────────────────────────────────────

# Pide el resumen competitivo al API y lo muestra cuando llega.
# Si no hay sesión activa o falla, la tarjeta queda oculta (no bloquea).
func cargar_y_mostrar() -> void:
	if _cargando:
		return
	if not AuthApi.esta_logueado():
		visible = false
		return

	_cargando = true
	_mostrar_estado_carga()

	var resultado := await LeaderboardApi.obtener_resumen_competitivo()
	_cargando = false

	if not resultado.get("ok", false):
		visible = false
		return

	var datos: Variant = resultado.get("data", resultado)
	if datos is Dictionary:
		mostrar_desde_datos(datos as Dictionary)
	else:
		visible = false


# Llena la tarjeta con los datos ya parseados del endpoint /me/summary.
# datos = { available, current, next, exp_to_next_rank, progress_to_next_rank, is_first_place }
func mostrar_desde_datos(datos: Dictionary) -> void:
	if not datos.get("available", true):
		visible = false
		return

	visible = true
	_contenedor_datos.visible = true
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = false

	var es_primero: bool = bool(datos.get("is_first_place", false))
	var current: Variant = datos.get("current", {})
	if not current is Dictionary:
		visible = false
		return

	var puesto: int   = int((current as Dictionary).get("rank", 0))
	var exp_actual: int = int((current as Dictionary).get("score", 0))
	var exp_faltante: int = int(datos.get("exp_to_next_rank", 0))
	var progreso: float   = float(datos.get("progress_to_next_rank", 0))

	_label_puesto.text = _texto_puesto(puesto)

	if es_primero:
		_label_meta.text = "¡Estás en el primer puesto! 🏆"
	else:
		var siguiente: Variant = datos.get("next", {})
		var nombre_rival := _nombre_rival(siguiente)
		_label_meta.text = "Te faltan %s EXP para superar a %s" % [
			_formatear_exp(exp_faltante),
			nombre_rival
		]

	# Animar los valores en lugar de setearlos de golpe
	_animar_valores(exp_actual, progreso)


# ── Internos ───────────────────────────────────────────────────────────────────

func _animar_valores(exp_meta: int, progreso_meta: float) -> void:
	# Reseteamos valores visuales antes de la animación
	_label_exp.text = _formatear_exp(0)
	if is_instance_valid(_barra_progreso):
		_barra_progreso.min_value = 0.0
		_barra_progreso.max_value = 100.0
		_barra_progreso.value = 0.0

	# Creamos un tween paralelo para animar barra y texto al mismo tiempo
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 1. Animar barra de progreso (duración: 1 segundo)
	if is_instance_valid(_barra_progreso):
		tween.tween_property(_barra_progreso, "value", progreso_meta, 1.0)

	# 2. Animar texto de EXP (duración: 1 segundo). Usamos un tween_method para llamar a un setter.
	tween.tween_method(_setear_texto_exp_animado, 0, exp_meta, 1.0)


func _setear_texto_exp_animado(valor_actual: int) -> void:
	if is_instance_valid(_label_exp):
		_label_exp.text = _formatear_exp(valor_actual)


func _mostrar_estado_carga() -> void:
	if is_instance_valid(_contenedor_carga):
		_contenedor_carga.visible = true
	_contenedor_datos.visible = false


# Las primeras 3 posiciones muestran medalla, el resto muestra "#N".
func _texto_puesto(puesto: int) -> String:
	match puesto:
		1: return "🥇"
		2: return "🥈"
		3: return "🥉"
		_: return "#%d" % puesto if puesto > 0 else "—"


func _formatear_exp(exp: int) -> String:
	if exp >= 1_000_000:
		return "%.1fM XP" % (float(exp) / 1_000_000)
	if exp >= 1_000:
		return "%.1fK XP" % (float(exp) / 1_000)
	return "%d XP" % exp


# Extrae el nombre más legible del rival (displayName > username > "#N").
func _nombre_rival(siguiente: Variant) -> String:
	if not siguiente is Dictionary:
		return "el jugador anterior"
	var sig := siguiente as Dictionary
	var display: Variant = sig.get("display_name", null)
	if display != null and display is String and not (display as String).is_empty():
		return display as String
	var username: Variant = sig.get("username", "")
	if username is String and not (username as String).is_empty():
		return username as String
	var puesto: int = int(sig.get("rank", 0))
	return "puesto #%d" % puesto if puesto > 0 else "el jugador anterior"
