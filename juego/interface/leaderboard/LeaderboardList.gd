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
signal entrada_seleccionada(id_usuario: String, entrada: Dictionary)


# ── Recursos ───────────────────────────────────────────────────────────────────

const ESCENA_ENTRADA := preload("res://interface/leaderboard/LeaderboardEntry.tscn")


# ── Exports ────────────────────────────────────────────────────────────────────

# Si false, el botón "Ver más" nunca aparece (útil en modos compactos).
@export var mostrar_boton_ver_mas: bool = true

# Si > 0, omite esos ranks de la lista (se muestran en el podio).
@export var omitir_top_en_podium: int = 3

@export var duracion_scroll_animado: float = 0.38


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _contenedor:    VBoxContainer = $VBoxContainer
@onready var _boton_ver_mas: Button        = $VBoxContainer/BotonVerMas


# ── Estado interno ─────────────────────────────────────────────────────────────

var _scope_actual: String   = "global_xp"  # Scope que está mostrando actualmente.
var _id_propio: String      = ""           # ID del jugador logueado (para resaltarlo).
var _desplazamiento: int    = 0            # Offset de la próxima página a pedir.
var _offset_actual: int     = 0            # Offset de la página mostrada actualmente.
var _total: int             = 0            # Total de entradas en el servidor.
var _tween_scroll: Tween    = null


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	if is_instance_valid(_boton_ver_mas):
		_boton_ver_mas.visible = false
		_boton_ver_mas.pressed.connect(_al_presionar_ver_mas)
	if not LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.connect(_al_avatar_cargado)


func _exit_tree() -> void:
	if LeaderboardAvatarCache.avatar_cargado.is_connected(_al_avatar_cargado):
		LeaderboardAvatarCache.avatar_cargado.disconnect(_al_avatar_cargado)


# ── API pública ────────────────────────────────────────────────────────────────

# Llena la lista completa con los datos del API (borra lo que hubiera antes).
# datos = { scope, entries: Array, total, pagination: { limit, offset, hasMore } }
func poblar(datos: Dictionary, id_propio: String = "", omitir_top: int = -1) -> void:
	_scope_actual = str(datos.get("scope", "global_xp"))
	_id_propio    = id_propio
	_total        = int(datos.get("total", 0))
	_limpiar_filas()

	var entradas: Variant = datos.get("entries", [])
	if not entradas is Array:
		return

	var limite_omitir := omitir_top if omitir_top >= 0 else omitir_top_en_podium
	for entrada in (entradas as Array):
		if entrada is Dictionary:
			var entry := entrada as Dictionary
			var rank := int(entry.get("rank", 0))
			if limite_omitir > 0 and rank >= 1 and rank <= limite_omitir:
				continue
			var es_propio := str(entry.get("user_id", "")) == _id_propio
			_agregar_fila(entry, es_propio)

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
	_offset_actual = 0


# Desplaza el scroll hasta la fila del usuario logueado, si está visible.
func scroll_a_usuario(id_usuario: String, animado: bool = true) -> bool:
	var fila := _buscar_fila_usuario(id_usuario)
	if fila == null:
		return false
	if animado:
		_scroll_animado_a_control(fila)
	else:
		ensure_control_visible(fila)
		if fila is LeaderboardEntry:
			(fila as LeaderboardEntry).animar_atencion()
	return true


func _buscar_fila_usuario(id_usuario: String) -> Control:
	if id_usuario.is_empty() or not is_instance_valid(_contenedor):
		return null
	for hijo in _contenedor.get_children():
		if hijo == _boton_ver_mas:
			continue
		if hijo is LeaderboardEntry and (hijo as LeaderboardEntry).es_usuario(id_usuario):
			return hijo as Control
	return null


func _scroll_animado_a_control(control: Control) -> void:
	if _tween_scroll != null and _tween_scroll.is_valid():
		_tween_scroll.kill()

	call_deferred("_ejecutar_scroll_animado", control)


func _ejecutar_scroll_animado(control: Control) -> void:
	if not is_instance_valid(control):
		return

	await get_tree().process_frame

	var barra := get_v_scroll_bar()
	var max_scroll := int(barra.max_value) if barra != null else 0
	var objetivo := _calcular_scroll_para_centrar(control, max_scroll)

	if abs(objetivo - scroll_vertical) <= 2:
		scroll_vertical = objetivo
		if control is LeaderboardEntry:
			(control as LeaderboardEntry).animar_atencion()
		return

	_tween_scroll = create_tween()
	_tween_scroll.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_scroll.tween_property(self, "scroll_vertical", objetivo, duracion_scroll_animado)
	_tween_scroll.finished.connect(
		func() -> void:
			if is_instance_valid(control) and control is LeaderboardEntry:
				(control as LeaderboardEntry).animar_atencion(),
		CONNECT_ONE_SHOT
	)


func _calcular_scroll_para_centrar(control: Control, max_scroll: int) -> int:
	var fila_y := int(control.position.y)
	var fila_h := int(control.size.y)
	var viewport_h := int(size.y)
	var objetivo := fila_y - int((viewport_h - fila_h) * 0.5)
	return clampi(objetivo, 0, max_scroll)


func contiene_usuario(id_usuario: String) -> bool:
	if id_usuario.is_empty() or not is_instance_valid(_contenedor):
		return false
	for hijo in _contenedor.get_children():
		if hijo == _boton_ver_mas:
			continue
		if hijo is LeaderboardEntry and (hijo as LeaderboardEntry).es_usuario(id_usuario):
			return true
	return false


func obtener_offset_actual() -> int:
	return _offset_actual


func mostrar_cargando(activo: bool) -> void:
	modulate.a = 0.45 if activo else 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE if activo else Control.MOUSE_FILTER_PASS


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
	fila.poblar(entrada, es_propio, _scope_actual)
	fila.entrada_presionada.connect(
		func(id_usuario: String, entrada: Dictionary) -> void:
			entrada_seleccionada.emit(id_usuario, entrada)
	)


# Lee la paginación del diccionario de datos y actualiza el offset y el botón.
func _actualizar_paginacion(datos: Dictionary) -> void:
	var paginacion: Variant = datos.get("pagination", {})
	if not paginacion is Dictionary:
		return
	var pag := paginacion as Dictionary
	_offset_actual = int(pag.get("offset", 0))
	_desplazamiento = _offset_actual + int(pag.get("limit", 50))
	var hay_mas: bool = bool(pag.get("hasMore", false))
	_mostrar_boton_ver_mas(hay_mas)


func _mostrar_boton_ver_mas(hay_mas: bool) -> void:
	if is_instance_valid(_boton_ver_mas):
		_boton_ver_mas.visible = mostrar_boton_ver_mas and hay_mas


# ── Callbacks ──────────────────────────────────────────────────────────────────

func _al_presionar_ver_mas() -> void:
	cargar_mas_solicitado.emit(_scope_actual, _desplazamiento)


func _al_avatar_cargado(user_id: String, _texture: Texture2D) -> void:
	for hijo in _contenedor.get_children():
		if hijo == _boton_ver_mas:
			continue
		if hijo is LeaderboardEntry:
			(hijo as LeaderboardEntry).refrescar_avatar_si_coincide(user_id)
