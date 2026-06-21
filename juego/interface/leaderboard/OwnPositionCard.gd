class_name OwnPositionCard
extends PanelContainer

# Tarjeta fija que muestra la posición del jugador logueado en el ranking.
#
# Solo es visible si hay sesión activa.
# Si el jugador no aparece en el snapshot, muestra un mensaje de incentivo.
# Se actualiza automáticamente cuando LeaderboardService emite "posicion_propia_cargada".


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _label_posicion: Label = $MarginContainer/HBox/RankLabel
@onready var _label_puntaje:  Label = $MarginContainer/HBox/ScoreLabel
@onready var _label_texto:    Label = $MarginContainer/HBox/TextoLabel


# ── Estado interno ─────────────────────────────────────────────────────────────

# Scope que está esperando la respuesta de posición propia.
var _scope_pendiente: String = "global_xp"


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false
	LeaderboardService.posicion_propia_cargada.connect(_al_cargar_posicion)


func _exit_tree() -> void:
	if LeaderboardService.posicion_propia_cargada.is_connected(_al_cargar_posicion):
		LeaderboardService.posicion_propia_cargada.disconnect(_al_cargar_posicion)


# ── API pública ────────────────────────────────────────────────────────────────

# Actualiza la tarjeta con los datos de posición de un scope específico.
# posiciones = Array de { scope, rank, score } que devuelve el API.
func mostrar_para_scope(scope: String, posiciones: Array) -> void:
	if not AuthApi.esta_logueado():
		visible = false
		return

	visible = true
	var posicion: Dictionary = _buscar_posicion_para_scope(scope, posiciones)

	if posicion.is_empty() or posicion.get("rank") == null:
		_mostrar_sin_rankear()
		return

	_mostrar_posicion(int(posicion.get("rank", 0)), int(posicion.get("score", 0)))


# Solicita al servicio que cargue la posición propia y luego la muestra.
func cargar_y_mostrar(scope: String) -> void:
	if not AuthApi.esta_logueado():
		visible = false
		return
	_scope_pendiente = scope
	LeaderboardService.cargar_posicion_propia()


# ── Internos ───────────────────────────────────────────────────────────────────

func _mostrar_posicion(posicion: int, puntaje: int) -> void:
	_label_posicion.text = "#%d" % posicion
	_label_puntaje.text  = _formatear_puntaje(puntaje)
	_label_texto.text    = "Tu posición"


func _mostrar_sin_rankear() -> void:
	_label_posicion.text = "—"
	_label_puntaje.text  = ""
	_label_texto.text    = "Jugá para aparecer en el ranking"


# Busca dentro del array de posiciones la que corresponde al scope dado.
func _buscar_posicion_para_scope(scope: String, posiciones: Array) -> Dictionary:
	for posicion in posiciones:
		if posicion is Dictionary and str(posicion.get("scope", "")) == scope:
			return posicion as Dictionary
	return {}


func _formatear_puntaje(puntaje: int) -> String:
	if puntaje >= 1_000_000:
		return "%.1fM XP" % (float(puntaje) / 1_000_000)
	if puntaje >= 1_000:
		return "%.1fK XP" % (float(puntaje) / 1_000)
	return "%d XP" % puntaje


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _al_cargar_posicion(posiciones: Array) -> void:
	mostrar_para_scope(_scope_pendiente, posiciones)
