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
@onready var _podio:               LeaderboardPodium = %LeaderboardPodium
@onready var _lista:               LeaderboardList = %LeaderboardList
@onready var _card_posicion_propia: OwnPositionCard = %OwnPositionCard
@onready var _boton_cerrar:        Button          = %BotonCerrar
@onready var _boton_reintentar:    Button          = %BotonReintentar
@onready var _panel_central:       PanelContainer  = %PanelCentral
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
var _rank_propio_actual: int = 0
var _offset_lista_actual: int = 0
var _entradas_podio_cache: Array = []


# ── Ciclo de vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 80

	_id_usuario_propio = _obtener_id_usuario_logueado()

	_conectar_servicio()
	_conectar_componentes()

	if not AuthApi.esta_logueado() and is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_modo_solo_lectura()

	_preparar_fade_inicial()
	_animar_entrada()


func _exit_tree() -> void:
	_desconectar_servicio()


func _input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		_cerrar()
		get_viewport().set_input_as_handled()


# ── API pública ────────────────────────────────────────────────────────────────

func abrir(scope: String = "") -> void:
	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = LeaderboardOverlayHelper.scope_desde_arbol(get_tree())
	_scope_activo = scope_final
	if is_instance_valid(_pestanias):
		_pestanias.seleccionar(scope_final)
	_cargar_scope(scope_final)


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
		_card_posicion_propia.ir_a_posicion_solicitada.connect(_al_ir_a_posicion_solicitada)
		_card_posicion_propia.volver_al_top_solicitado.connect(_al_volver_al_top_solicitado)
	if is_instance_valid(_panel_vacio) and _panel_vacio.has_signal("iniciar_sesion_solicitado"):
		_panel_vacio.iniciar_sesion_solicitado.connect(_al_iniciar_sesion_solicitado)


# ── Carga y estados ────────────────────────────────────────────────────────────

func _cargar_scope(scope: String, forzar: bool = false) -> void:
	_scope_activo = scope
	_offset_lista_actual = 0
	_entradas_podio_cache.clear()
	_ocultar_peek_entrada()
	if is_instance_valid(_podio):
		_podio.limpiar()
	if is_instance_valid(_lista):
		_lista.limpiar()
		_lista.mostrar_cargando(false)
	_cambiar_estado(EstadoUi.CARGANDO)
	if not AuthApi.esta_logueado() and is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_modo_solo_lectura()
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
	if not AuthApi.esta_logueado():
		var hint := LeaderboardFormat.hint_meta_modo_invitado()
		texto = hint if texto.is_empty() else "%s · %s" % [texto, hint]
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
	var scope_base := scope
	if scope.ends_with(":mas"):
		if scope.trim_suffix(":mas") != _scope_activo:
			return
		if is_instance_valid(_lista):
			_lista.agregar_mas(datos)
			_actualizar_accion_posicion_propia(datos)
		return

	if scope.ends_with(":pagina"):
		scope_base = scope.trim_suffix(":pagina")
		if scope_base != _scope_activo:
			return
		if is_instance_valid(_lista):
			_lista.poblar(datos, _id_usuario_propio, 0)
			_lista.mostrar_cargando(false)
			_offset_lista_actual = _lista.obtener_offset_actual()
		_restaurar_podio_si_hace_falta()
		if is_instance_valid(_card_posicion_propia):
			_card_posicion_propia.mostrar_desde_respuesta_leaderboard(_scope_activo, datos)
			_card_posicion_propia.marcar_buscando_posicion(false)
		_actualizar_accion_posicion_propia(datos)
		_actualizar_meta(datos)
		_cambiar_estado(EstadoUi.DATOS)
		call_deferred("_deferred_scroll_a_usuario")
		return

	if scope_base != _scope_activo:
		return

	var entradas: Variant = datos.get("entries", [])
	if entradas is Array and (entradas as Array).is_empty():
		_actualizar_meta(datos)
		if is_instance_valid(_podio):
			_podio.limpiar()
		if is_instance_valid(_card_posicion_propia):
			_card_posicion_propia.mostrar_desde_respuesta_leaderboard(_scope_activo, datos)
		_cambiar_estado(EstadoUi.VACIO)
		return

	var entries_array := entradas as Array if entradas is Array else []
	_guardar_entradas_podio(entries_array)
	if is_instance_valid(_podio):
		_podio.poblar(_entradas_podio_cache, _scope_activo, _id_usuario_propio)

	if is_instance_valid(_lista):
		_lista.poblar(datos, _id_usuario_propio)
		_lista.mostrar_cargando(false)
		_offset_lista_actual = _lista.obtener_offset_actual()

	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.mostrar_desde_respuesta_leaderboard(_scope_activo, datos)

	_actualizar_meta(datos)
	_cambiar_estado(EstadoUi.DATOS)
	_actualizar_accion_posicion_propia(datos)
	_scroll_a_fila_propia_si_corresponde(datos)
	_prefetch_scope_alternativo()


func _al_leaderboard_fallido(scope: String, mensaje: String) -> void:
	var scope_base := scope
	if scope.ends_with(":pagina"):
		scope_base = scope.trim_suffix(":pagina")
	if scope_base != _scope_activo:
		return
	if is_instance_valid(_lista):
		_lista.mostrar_cargando(false)
	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.marcar_buscando_posicion(false)
	if is_instance_valid(_etiqueta_error):
		var texto := mensaje.strip_edges()
		if texto.is_empty():
			texto = "No se pudo cargar el ranking."
		if not AuthApi.esta_logueado():
			texto += "\n%s" % LeaderboardFormat.mensaje_progreso_no_suma()
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


func _obtener_rank_propio(datos: Dictionary) -> int:
	var own: Variant = datos.get("own_position", null)
	if own is Dictionary and (own as Dictionary).get("rank") != null:
		return int((own as Dictionary).get("rank", 0))

	if _id_usuario_propio.is_empty():
		return 0

	for entrada in datos.get("entries", []) as Array:
		if entrada is Dictionary:
			var entry := entrada as Dictionary
			if str(entry.get("user_id", "")) == _id_usuario_propio:
				return int(entry.get("rank", 0))
	return 0


func _scroll_a_fila_propia_si_corresponde(datos: Dictionary) -> void:
	if _id_usuario_propio.is_empty() or not is_instance_valid(_lista):
		return
	var rank := _obtener_rank_propio(datos)
	if rank <= 3:
		return
	if _lista.contiene_usuario(_id_usuario_propio):
		call_deferred("_deferred_scroll_a_usuario")


func _actualizar_accion_posicion_propia(datos: Dictionary) -> void:
	if not is_instance_valid(_card_posicion_propia) or not AuthApi.esta_logueado():
		return
	var rank := _obtener_rank_propio(datos)
	_rank_propio_actual = rank
	if rank <= 0:
		_card_posicion_propia.configurar_navegacion(0, true, _offset_lista_actual)
		return
	var visible_en_lista := rank <= 3
	if is_instance_valid(_lista):
		visible_en_lista = visible_en_lista or _lista.contiene_usuario(_id_usuario_propio)
	_card_posicion_propia.configurar_navegacion(rank, visible_en_lista, _offset_lista_actual)


func _al_ir_a_posicion_solicitada(rank: int) -> void:
	if rank <= 3 or _scope_activo.is_empty():
		return
	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.marcar_buscando_posicion(true)
	if is_instance_valid(_lista):
		_lista.mostrar_cargando(true)
	var pagina_offset := LeaderboardService.calcular_offset_para_rank(rank)
	_offset_lista_actual = pagina_offset
	LeaderboardService.cargar(_scope_activo, true, pagina_offset)


func _al_volver_al_top_solicitado() -> void:
	if _scope_activo.is_empty():
		return
	_offset_lista_actual = 0
	if is_instance_valid(_lista):
		_lista.mostrar_cargando(true)
	LeaderboardService.cargar(_scope_activo, false, 0)


func _guardar_entradas_podio(entradas: Array) -> void:
	_entradas_podio_cache.clear()
	for entrada in entradas:
		if entrada is Dictionary:
			var rank := int((entrada as Dictionary).get("rank", 0))
			if rank >= 1 and rank <= 3:
				_entradas_podio_cache.append(entrada)


func _restaurar_podio_si_hace_falta() -> void:
	if not is_instance_valid(_podio) or _entradas_podio_cache.is_empty():
		return
	_podio.poblar(_entradas_podio_cache, _scope_activo, _id_usuario_propio)


func _deferred_scroll_a_usuario() -> void:
	if not is_instance_valid(_lista):
		return
	if not _lista.scroll_a_usuario(_id_usuario_propio):
		return
	if is_instance_valid(_card_posicion_propia):
		_card_posicion_propia.configurar_navegacion(_rank_propio_actual, true, _offset_lista_actual)


func _al_seleccionar_entrada(id_usuario: String, entrada: Dictionary) -> void:
	if not is_instance_valid(_entry_peek):
		return
	var es_propio := id_usuario == _id_usuario_propio and not _id_usuario_propio.is_empty()
	_entry_peek.mostrar(entrada, _scope_activo, es_propio)
	_entry_peek.visible = true
