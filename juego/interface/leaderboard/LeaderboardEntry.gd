class_name LeaderboardEntry
extends HBoxContainer

# Fila individual dentro de la lista del leaderboard.
#
# Muestra la posición (#1, #2... o medalla 🥇🥈🥉), el nombre del jugador
# y su puntaje formateado (ej: 12.4K, 1.2M).
# Si la fila corresponde al jugador logueado, se resalta con un fondo de color.


# ── Señales ────────────────────────────────────────────────────────────────────

# Emitida cuando el jugador toca esta fila.
signal entrada_presionada(id_usuario: String)


# ── Configuración visual (exportada al editor) ─────────────────────────────────

@export var color_medalla_oro:    Color = Color("FFD700")  # #1
@export var color_medalla_plata:  Color = Color("C0C0C0")  # #2
@export var color_medalla_bronce: Color = Color("CD7F32")  # #3
@export var color_fila_propia:    Color = Color(1, 1, 1, 0.15)  # jugador logueado


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _label_posicion: Label     = $RankLabel
@onready var _label_nombre:   Label     = $NombreLabel
@onready var _label_puntaje:  Label     = $ScoreLabel
@onready var _fondo_destacado: ColorRect = $BgHighlight
@onready var _boton_area:     Button    = $BotonArea


# ── Estado interno ─────────────────────────────────────────────────────────────

var _id_usuario: String = ""


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	if is_instance_valid(_boton_area):
		_boton_area.pressed.connect(_al_presionar_fila)
	if is_instance_valid(_fondo_destacado):
		_fondo_destacado.visible = false


# ── API pública ────────────────────────────────────────────────────────────────

# Llena la fila con los datos de una entrada del API.
# entrada = { rank, user_id, username, display_name, score }
# es_propio = true si este jugador es el que está logueado actualmente.
func poblar(entrada: Dictionary, es_propio: bool = false) -> void:
	_id_usuario = str(entrada.get("user_id", ""))

	var posicion: int  = int(entrada.get("rank", 0))
	var puntaje: int   = int(entrada.get("score", 0))
	var nombre: String = _resolver_nombre(entrada)

	_label_posicion.text = _texto_posicion(posicion)
	_label_nombre.text   = nombre
	_label_puntaje.text  = _formatear_puntaje(puntaje)

	_aplicar_color_posicion(posicion, es_propio)
	_aplicar_fondo_destacado(es_propio)


# ── Internos ───────────────────────────────────────────────────────────────────

# Prioriza el display_name si existe, si no usa el username.
func _resolver_nombre(entrada: Dictionary) -> String:
	var nombre_visible: Variant = entrada.get("display_name", null)
	if nombre_visible != null and nombre_visible is String and not (nombre_visible as String).is_empty():
		return nombre_visible as String
	var nombre_usuario: Variant = entrada.get("username", "")
	return nombre_usuario as String if nombre_usuario is String else "—"


# Las primeras 3 posiciones muestran medallas, el resto muestra "#N".
func _texto_posicion(posicion: int) -> String:
	match posicion:
		1: return "🥇"
		2: return "🥈"
		3: return "🥉"
		_: return "#%d" % posicion


# Formatea el puntaje con sufijo K o M para que sea legible.
func _formatear_puntaje(puntaje: int) -> String:
	if puntaje >= 1_000_000:
		return "%.1fM" % (float(puntaje) / 1_000_000)
	if puntaje >= 1_000:
		return "%.1fK" % (float(puntaje) / 1_000)
	return str(puntaje)


# Colorea el label de posición según el puesto o si es el jugador propio.
func _aplicar_color_posicion(posicion: int, es_propio: bool) -> void:
	if not is_instance_valid(_label_posicion):
		return
	if es_propio:
		_label_posicion.add_theme_color_override("font_color", Color.WHITE)
		return
	match posicion:
		1: _label_posicion.add_theme_color_override("font_color", color_medalla_oro)
		2: _label_posicion.add_theme_color_override("font_color", color_medalla_plata)
		3: _label_posicion.add_theme_color_override("font_color", color_medalla_bronce)
		_: _label_posicion.remove_theme_color_override("font_color")


# Muestra u oculta el fondo de color que resalta la fila propia.
func _aplicar_fondo_destacado(es_propio: bool) -> void:
	if not is_instance_valid(_fondo_destacado):
		return
	_fondo_destacado.visible = es_propio
	if es_propio:
		_fondo_destacado.color = color_fila_propia


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _al_presionar_fila() -> void:
	if not _id_usuario.is_empty():
		entrada_presionada.emit(_id_usuario)
