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

signal cerrado


# ── Estados posibles de la UI ─────────────────────────────────────────────────

enum EstadoUi {
	INACTIVO,
	CARGANDO,
	DATOS,
	VACIO,
	ERROR,
}


# ── Nodos de la escena ─────────────────────────────────────────────────────────

@onready var _pestanias:           ScopeTabs       = %ScopeTabs
@onready var _lista:               LeaderboardList = %LeaderboardList
@onready var _card_posicion_propia: OwnPositionCard = %OwnPositionCard
@onready var _boton_cerrar:        Button          = %BotonCerrar
@onready var _boton_reintentar:    Button          = %BotonReintentar
@onready var _panel_central:       PanelContainer  = %PanelCentral
@onready var _header_bar:          PanelContainer  = %HeaderBar
@onready var _titulo:              Label           = %TituloLabel
@onready var _label_meta:          Label           = %LabelMeta
@onready var _contenedor_datos:    Control         = %ContenedorDatos
@onready var _contenedor_cargando: Control         = %ContenedorCarga
@onready var _contenedor_error:    Control         = %ContenedorError
@onready var _contenedor_vacio:    Control         = %ContenedorVacio
@onready var _panel_vacio:        VBoxContainer   = %ContenedorVacio/LeaderboardEmpty
@onready var _etiqueta_error:      Label           = %LabelError
@onready var _entry_peek:          LeaderboardEntryPeek = %EntryPeek
@onready var _fondo:               PanelContainer  = $Fondo


# ── Estado interno ─────────────────────────────────────────────────────────────

var _estado_actual: EstadoUi = EstadoUi.INACTIVO
var _scope_activo: String = "global_xp"
var _id_usuario_propio: String = ""


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 80

	_id_usuario_propio = _obtener_id_usuario_logueado()

	_conectar_servicio()
	_conectar_componentes()

	if not AuthApi.esta_logueado() and is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_invitacion_login()

	_preparar_fade_inicial()
	_cargar_scope(_scope_activo)
	_animar_entrada()


func _exit_tree() -> void:
	_desconectar_servicio()


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()


# ── API pública ────────────────────────────────────────────────────────────────

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
	if is_instance_valid(_boton_reintentar):
		_boton_reintentar.pressed.connect(_al_presionar_reintentar)
	if is_instance_valid(_lista):
		_lista.cargar_mas_solicitado.connect(_al_solicitar_mas)
		_lista.entrada_seleccionada.connect(_al_seleccionar_entrada)
	if is_instance_valid(_entry_peek):
		_entry_peek.cerrado.connect(_ocultar_peek_entrada)
	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.iniciar_sesion_solicitado.connect(_al_iniciar_sesion_solicitado)
	if is_instance_valid(_panel_vacio) and _panel_vacio.has_signal("iniciar_sesion_solicitado"):
		_panel_vacio.iniciar_sesion_solicitado.connect(_al_iniciar_sesion_solicitado)


# ── Carga y estados ────────────────────────────────────────────────────────────

func _cargar_scope(scope: String, forzar: bool = false) -> void:
	_scope_activo = scope
	_ocultar_peek_entrada()
	_cambiar_estado(EstadoUi.CARGANDO)
	if not AuthApi.esta_logueado() and is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_invitacion_login()
	if forzar:
		LeaderboardService.invalidar_cache(scope)
	LeaderboardService.cargar(scope, forzar)
	if is_instance_valid(_label_meta):
		_label_meta.text = ""
		_label_meta.visible = false


func _cambiar_estado(nuevo_estado: EstadoUi) -> void:
	_estado_actual = nuevo_estado
	if nuevo_estado == EstadoUi.VACIO:
		_configurar_estado_vacio()
	var mapa_visibilidad: Dictionary = {
		EstadoUi.CARGANDO: _contenedor_cargando,
		EstadoUi.DATOS:    _contenedor_datos,
		EstadoUi.ERROR:    _contenedor_error,
		EstadoUi.VACIO:    _contenedor_vacio,
	}
	for estado: EstadoUi in mapa_visibilidad:
		var nodo: Control = mapa_visibilidad[estado]
		if is_instance_valid(nodo):
			nodo.visible = (estado == nuevo_estado)


func _actualizar_meta(datos: Dictionary) -> void:
	if not is_instance_valid(_label_meta):
		return
	var texto := LeaderboardFormat.texto_meta(datos)
	_label_meta.text = texto
	_label_meta.visible = not texto.is_empty()


func _configurar_estado_vacio() -> void:
	if is_instance_valid(_panel_vacio) and _panel_vacio.has_method("configurar_para_jugador"):
		_panel_vacio.call("configurar_para_jugador", not AuthApi.esta_logueado())


func _al_iniciar_sesion_solicitado() -> void:
	var helper := AuthLoginOverlayHelper.new()
	await helper.mostrar_y_esperar(self, AuthLoginOverlayHelper.FLUJO_JUEGO)
	if not AuthApi.esta_logueado():
		return
	_id_usuario_propio = _obtener_id_usuario_logueado()
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)
	_cargar_scope(_scope_activo, true)


# ── Animaciones ────────────────────────────────────────────────────────────────

func _animar_entrada() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_fondo):
		tween.tween_property(_fondo, "modulate:a", 1.0, 0.25)
	if is_instance_valid(_panel_central):
		tween.tween_property(_panel_central, "modulate:a", 1.0, 0.25)


func _animar_salida() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(_fondo):
		tween.tween_property(_fondo, "modulate:a", 0.0, 0.2)
	if is_instance_valid(_panel_central):
		tween.tween_property(_panel_central, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(func() -> void:
		cerrado.emit()
		queue_free()
	)


func _preparar_fade_inicial() -> void:
	if is_instance_valid(_fondo):
		_fondo.modulate.a = 0.0
	if is_instance_valid(_panel_central):
		_panel_central.modulate.a = 0.0


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
	if scope != _scope_activo and not scope.ends_with(":mas"):
		return

	if scope.ends_with(":mas"):
		if is_instance_valid(_lista):
			_lista.agregar_mas(datos)
		return

	var entradas: Variant = datos.get("entries", [])
	if entradas is Array and (entradas as Array).is_empty():
		_actualizar_meta(datos)
		if is_instance_valid(_card_posicion_propia):
			_card_posicion_propia.mostrar_desde_respuesta_leaderboard(_scope_activo, datos)
		_cambiar_estado(EstadoUi.VACIO)
		return

	if is_instance_valid(_lista):
		_lista.poblar(datos, _id_usuario_propio)

	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_desde_respuesta_leaderboard(_scope_activo, datos)

	_actualizar_meta(datos)
	_cambiar_estado(EstadoUi.DATOS)
	_prefetch_scope_alternativo()


func _al_leaderboard_fallido(scope: String, mensaje: String) -> void:
	if scope != _scope_activo:
		return
	if is_instance_valid(_etiqueta_error):
		var texto := mensaje.strip_edges()
		if texto.is_empty():
			texto = "No se pudo cargar el ranking."
		if not AuthApi.esta_logueado():
			texto += "\nPodés ver el ranking global; iniciá sesión para tu posición."
		_etiqueta_error.text = texto
	_cambiar_estado(EstadoUi.ERROR)


func _al_presionar_reintentar() -> void:
	_cargar_scope(_scope_activo, true)


func _al_solicitar_mas(scope: String, desplazamiento: int) -> void:
	LeaderboardService.cargar_mas(scope, desplazamiento)


func _prefetch_scope_alternativo() -> void:
	LeaderboardService.prefetch(LeaderboardScopeCatalog.siguiente_scope(_scope_activo))


func _ocultar_peek_entrada() -> void:
	if is_instance_valid(_entry_peek):
		_entry_peek.visible = false


func _al_seleccionar_entrada(id_usuario: String, entrada: Dictionary) -> void:
	if not is_instance_valid(_entry_peek):
		return
	var es_propio := id_usuario == _id_usuario_propio and not _id_usuario_propio.is_empty()
	_entry_peek.mostrar(entrada, _scope_activo, es_propio)
	_entry_peek.visible = true
