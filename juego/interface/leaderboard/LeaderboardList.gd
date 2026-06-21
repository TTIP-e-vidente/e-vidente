class_name LeaderboardList
extends ScrollContainer

# Lista scrolleable del leaderboard.
#
# Muestra filas (LeaderboardEntry) para cada jugador del ranking.
# Soporta paginación: al tocar "Ver más" pide la siguiente página.
# Las filas se insertan dinámicamente al recibir datos del API.


# ── Señales ────────────────────────────────────────────────────────────────────

# Emitida cuando el jugador pide la siguiente página. Lleva el scope y desde qué posición.
signal cargar_mas_solicitado(scope: String, desplazamiento: int)

# Emitida cuando el jugador toca una fila del ranking.
signal entrada_seleccionada(id_usuario: String)


# ── Recursos ───────────────────────────────────────────────────────────────────

const ESCENA_ENTRADA := preload("res://interface/leaderboard/LeaderboardEntry.tscn")


# ── Exports ────────────────────────────────────────────────────────────────────

# Si false, el botón "Ver más" nunca aparece (útil en modos compactos).
@export var mostrar_boton_ver_mas: bool = true


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _contenedor:    VBoxContainer = $VBoxContainer
@onready var _boton_ver_mas: Button        = $VBoxContainer/BotonVerMas


# ── Estado interno ─────────────────────────────────────────────────────────────

var _scope_actual: String   = "global_xp"  # Scope que está mostrando actualmente.
var _id_propio: String      = ""           # ID del jugador logueado (para resaltarlo).
var _desplazamiento: int    = 0            # Offset de la próxima página a pedir.
var _total: int             = 0            # Total de entradas en el servidor.


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	if is_instance_valid(_boton_ver_mas):
		_boton_ver_mas.visible = false
		_boton_ver_mas.pressed.connect(_al_presionar_ver_mas)


# ── API pública ────────────────────────────────────────────────────────────────

# Llena la lista completa con los datos del API (borra lo que hubiera antes).
# datos = { scope, entries: Array, total, pagination: { limit, offset, hasMore } }
func poblar(datos: Dictionary, id_propio: String = "") -> void:
	_scope_actual = str(datos.get("scope", "global_xp"))
	_id_propio    = id_propio
	_total        = int(datos.get("total", 0))
	_limpiar_filas()

	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array:
		return

	for entrada in (entradas as Array):
		if entrada is Dictionary:
			var es_propio := str(entrada.get("user_id", "")) == _id_propio
			_agregar_fila(entrada as Dictionary, es_propio)

	_actualizar_paginacion(datos)


# Adjunta más entradas al final de la lista (paginación append).
func agregar_mas(datos: Dictionary) -> void:
	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array:
		return

	for entrada in (entradas as Array):
		if entrada is Dictionary:
			var es_propio := str(entrada.get("user_id", "")) == _id_propio
			_agregar_fila(entrada as Dictionary, es_propio)

	_actualizar_paginacion(datos)


# Elimina todas las filas de la lista.
func limpiar() -> void:
	_limpiar_filas()


# ── Internos ───────────────────────────────────────────────────────────────────

func _limpiar_filas() -> void:
	for hijo in _contenedor.get_children():
		if hijo != _boton_ver_mas:
			hijo.queue_free()


# Crea una fila nueva y la inserta antes del botón "Ver más".
func _agregar_fila(entrada: Dictionary, es_propio: bool) -> void:
	var fila := ESCENA_ENTRADA.instantiate() as LeaderboardEntry
	var posicion_boton := _contenedor.get_child_count() - 1
	_contenedor.add_child(fila)
	if posicion_boton >= 0:
		_contenedor.move_child(fila, posicion_boton)
	fila.poblar(entrada, es_propio)
	fila.entrada_presionada.connect(
		func(id_usuario: String) -> void: entrada_seleccionada.emit(id_usuario)
	)


# Lee la paginación del diccionario de datos y actualiza el offset y el botón.
func _actualizar_paginacion(datos: Dictionary) -> void:
	var paginacion: Variant = datos.get("pagination", {})
	if not paginacion is Dictionary:
		return
	var pag := paginacion as Dictionary
	_desplazamiento = int(pag.get("offset", 0)) + int(pag.get("limit", 50))
	var hay_mas: bool = bool(pag.get("hasMore", false))
	_mostrar_boton_ver_mas(hay_mas)


func _mostrar_boton_ver_mas(hay_mas: bool) -> void:
	if is_instance_valid(_boton_ver_mas):
		_boton_ver_mas.visible = mostrar_boton_ver_mas and hay_mas


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _al_presionar_ver_mas() -> void:
	cargar_mas_solicitado.emit(_scope_actual, _desplazamiento)
