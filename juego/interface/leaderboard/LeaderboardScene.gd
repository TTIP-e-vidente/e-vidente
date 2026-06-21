class_name LeaderboardScene
extends CanvasLayer

# Pantalla completa del leaderboard.
#
# Orquesta todos los componentes: ScopeTabs (pestañas), LeaderboardList (lista),
# OwnPositionCard (tu posición) y los contenedores de estado (cargando/vacío/error).
#
# Se instancia como overlay encima de la escena activa (layer 80, sobre el HUD en 75).
# Al cerrarse emite la señal "cerrado" y se destruye.


# ── Señales ────────────────────────────────────────────────────────────────────

# Emitida cuando el jugador cierra el leaderboard.
signal cerrado


# ── Estados posibles de la UI ─────────────────────────────────────────────────

enum Estado {
	INACTIVO,  # Pantalla recién creada, sin datos todavía.
	CARGANDO,  # Esperando respuesta del servidor.
	DATOS,     # Hay datos para mostrar en la lista.
	VACIO,     # La lista llegó vacía del servidor.
	ERROR,     # Hubo un error al cargar.
}


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _pestanias:           ScopeTabs       = %ScopeTabs
@onready var _lista:               LeaderboardList = %LeaderboardList
@onready var _card_posicion_propia: OwnPositionCard = %OwnPositionCard
@onready var _boton_cerrar:        Button          = %BotonCerrar
@onready var _contenedor_datos:    Control         = %ContenedorDatos
@onready var _contenedor_cargando: Control         = %ContenedorCarga
@onready var _contenedor_error:    Control         = %ContenedorError
@onready var _contenedor_vacio:    Control         = %ContenedorVacio
@onready var _etiqueta_error:      Label           = %LabelError


# ── Estado interno ─────────────────────────────────────────────────────────────

var _estado_actual: Estado = Estado.INACTIVO
var _scope_activo: String = "global_xp"
var _id_usuario_propio: String = ""


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 80  # Por encima del HUD global (layer 75).

	_id_usuario_propio = _obtener_id_usuario_logueado()

	_conectar_servicio()
	_conectar_componentes()

	modulate.a = 0.0
	_cargar_scope(_scope_activo)
	_animar_entrada()


func _exit_tree() -> void:
	_desconectar_servicio()


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()


# ── API pública ────────────────────────────────────────────────────────────────

# Abre el leaderboard mostrando un scope específico.
func abrir(scope: String = "global_xp") -> void:
	_scope_activo = scope
	if is_instance_valid(_pestanias):
		_pestanias.seleccionar(scope)
	_cargar_scope(scope)


# ── Conexiones ─────────────────────────────────────────────────────────────────

func _conectar_servicio() -> void:
	LeaderboardService.leaderboard_cargado.connect(_al_leaderboard_cargado)
	LeaderboardService.leaderboard_fallido.connect(_al_leaderboard_fallido)


func _desconectar_servicio() -> void:
	if LeaderboardService.leaderboard_cargado.is_connected(_al_leaderboard_cargado):
		LeaderboardService.leaderboard_cargado.disconnect(_al_leaderboard_cargado)
	if LeaderboardService.leaderboard_fallido.is_connected(_al_leaderboard_fallido):
		LeaderboardService.leaderboard_fallido.disconnect(_al_leaderboard_fallido)


func _conectar_componentes() -> void:
	if is_instance_valid(_pestanias):
		_pestanias.scope_cambiado.connect(_al_cambiar_scope)
	if is_instance_valid(_boton_cerrar):
		_boton_cerrar.pressed.connect(_cerrar)
	if is_instance_valid(_lista):
		_lista.cargar_mas_solicitado.connect(_al_solicitar_mas)
		_lista.entrada_seleccionada.connect(_al_seleccionar_entrada)


# ── Carga y estados ────────────────────────────────────────────────────────────

# Pide al servicio que cargue el scope dado y actualiza el estado a CARGANDO.
func _cargar_scope(scope: String) -> void:
	_scope_activo = scope
	_cambiar_estado(Estado.CARGANDO)
	LeaderboardService.cargar(scope)
	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.cargar_y_mostrar(scope)


# Cambia la visibilidad de los contenedores según el nuevo estado.
func _cambiar_estado(nuevo_estado: Estado) -> void:
	_estado_actual = nuevo_estado
	var mapa_visibilidad: Dictionary = {
		Estado.CARGANDO: _contenedor_cargando,
		Estado.DATOS:    _contenedor_datos,
		Estado.ERROR:    _contenedor_error,
		Estado.VACIO:    _contenedor_vacio,
	}
	for estado: Estado in mapa_visibilidad:
		var nodo: Control = mapa_visibilidad[estado]
		if is_instance_valid(nodo):
			nodo.visible = (estado == nuevo_estado)


# ── Animaciones ────────────────────────────────────────────────────────────────

func _animar_entrada() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animar_salida() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		cerrado.emit()
		queue_free()
	)


func _cerrar() -> void:
	_animar_salida()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _obtener_id_usuario_logueado() -> String:
	if not AuthApi.esta_logueado():
		return ""
	var datos_usuario := BackendSession.obtener_usuario_en_cache()
	return str(datos_usuario.get("id", ""))


# ── Callbacks de señales ───────────────────────────────────────────────────────

func _al_cambiar_scope(scope: String) -> void:
	_cargar_scope(scope)


func _al_leaderboard_cargado(scope: String, datos: Dictionary) -> void:
	# Ignorar respuestas de scopes que ya no son el activo.
	if scope != _scope_activo and not scope.ends_with(":mas"):
		return

	# Si es paginación extra, agregar al final de la lista existente.
	if scope.ends_with(":mas"):
		if is_instance_valid(_lista):
			_lista.agregar_mas(datos)
		return

	# Si llegaron 0 entradas, mostrar estado vacío.
	var entradas: Variant = datos.get("entries", [])
	if entradas is Array and (entradas as Array).is_empty():
		_cambiar_estado(Estado.VACIO)
		return

	if is_instance_valid(_lista):
		_lista.poblar(datos, _id_usuario_propio)

	_cambiar_estado(Estado.DATOS)


func _al_leaderboard_fallido(scope: String, mensaje: String) -> void:
	if scope != _scope_activo:
		return
	if is_instance_valid(_etiqueta_error):
		_etiqueta_error.text = mensaje
	_cambiar_estado(Estado.ERROR)


func _al_solicitar_mas(scope: String, desplazamiento: int) -> void:
	LeaderboardService.cargar_mas(scope, desplazamiento)


func _al_seleccionar_entrada(_id_usuario: String) -> void:
	# Hook para futura pantalla de perfil público del jugador.
	pass
