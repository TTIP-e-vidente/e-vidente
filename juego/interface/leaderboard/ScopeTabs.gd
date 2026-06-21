class_name ScopeTabs
extends HBoxContainer

# Selector de categorías (scopes) del leaderboard.
#
# Genera botones dinámicamente desde la lista SCOPES.
# Al cambiar de categoría emite "scope_cambiado" para que LeaderboardScene recargue la lista.
# No llama al API directamente: su responsabilidad es solo la UI.


# ── Señales ────────────────────────────────────────────────────────────────────

# Emitida cuando el jugador elige una categoría diferente.
signal scope_cambiado(scope: String)


# ── Categorías disponibles ─────────────────────────────────────────────────────

# Cada categoría tiene un "scope" (identificador del API) y un "etiqueta" (texto del botón).
const CATEGORIAS: Array[Dictionary] = [
	{"scope": "global_xp", "etiqueta": "XP Global"},
	{"scope": "streak",    "etiqueta": "Mejor Racha"},
]


# ── Configuración ──────────────────────────────────────────────────────────────

# Categoría seleccionada al abrir el leaderboard.
@export var categoria_inicial: String = "global_xp"


# ── Estado interno ─────────────────────────────────────────────────────────────

var _scope_activo: String = ""
var _botones: Array[Button] = []


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_construir_botones()
	seleccionar(categoria_inicial)


# ── API pública ────────────────────────────────────────────────────────────────

# Marca visualmente un scope como activo sin emitir la señal.
# Útil para sincronización externa (ej: cuando LeaderboardScene cambia el scope).
func seleccionar(scope: String) -> void:
	_scope_activo = scope
	for i in _botones.size():
		_botones[i].button_pressed = (CATEGORIAS[i]["scope"] == scope)


# Retorna el scope que está activo en este momento.
func obtener_scope_activo() -> String:
	return _scope_activo


# ── Internos ───────────────────────────────────────────────────────────────────

# Crea un botón por cada categoría definida en CATEGORIAS.
func _construir_botones() -> void:
	for categoria in CATEGORIAS:
		var boton := Button.new()
		boton.text                    = str(categoria["etiqueta"])
		boton.toggle_mode             = true
		boton.action_mode             = BaseButton.ACTION_MODE_BUTTON_PRESS
		boton.focus_mode              = Control.FOCUS_NONE
		boton.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		var scope_del_boton: String   = str(categoria["scope"])
		boton.pressed.connect(func() -> void: _al_presionar_tab(scope_del_boton))
		add_child(boton)
		_botones.append(boton)


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _al_presionar_tab(scope: String) -> void:
	if scope == _scope_activo:
		return  # Ya está activo, no hace falta recargar.
	_scope_activo = scope
	for i in _botones.size():
		_botones[i].button_pressed = (CATEGORIAS[i]["scope"] == scope)
	scope_cambiado.emit(scope)
