class_name SyncApi
extends RefCounted

# --- Partidas ----------------------------------------------------------------

## Devuelve true si hay sesión JWT activa y se puede intentar subir progreso.
static func puede_sincronizar() -> bool:
	return AuthApi.esta_logueado()


## POST legacy de un solo RunSummary. Usar solo en smoke/dev; el juego encola y hace batch.
static func guardar_partida_en_servidor(resumen_partida: Dictionary) -> Dictionary:
	return await BackendSession.guardar_progreso_online(resumen_partida)


## Resuelve `restriction` / `map_id` desde el resultado, sesión en [Global] o fallback de pista.
static func resolver_restriccion_para_partida(
	tree: SceneTree,
	resultado: Dictionary = {},
	pista_fallback: String = ""
) -> String:
	return SincronizadorPartida.resolver_restriccion(tree, resultado, pista_fallback)


## Construye RunSummary, encola en [LocalSyncQueue] y reintenta subida si hay sesión.
static func sincronizar_partida_terminada(
	tree: SceneTree,
	resultado: Dictionary,
	stats: Dictionary,
	pista_fallback: String = ""
) -> void:
	SincronizadorPartida.sincronizar_post_partida(tree, resultado, stats, pista_fallback)


# --- Cola y retry -------------------------------------------------------------


## Dispara vaciado de la cola (hasta 10 ítems por ronda; ver [BackendSession]).
static func reintentar_pendientes() -> void:
	BackendSession.reintentar_sync_pendiente()


## POST /player/me/progress/reset: borra progreso Celiaquía en servidor y actualiza cache online.
static func reiniciar_progreso_online(restriction: String = "CELIAQUIA") -> Dictionary:
	return await BackendSession.reiniciar_progreso_online(restriction)


## Reintenta hasta 100 ítems; usar desde perfil ("Guardar ahora") o colas grandes.
static func reintentar_todos_pendientes() -> void:
	BackendSession.reintentar_todos_sync_pendiente()


## True mientras corre un batch POST en [ProgressSyncService].
static func esta_sincronizando_pendientes() -> bool:
	return BackendSession.esta_sincronizando_sync()


## Espera a que la cola se drene; [AuthApi] lo usa antes de cerrar sesión.
static func esperar_drenaje_pendientes() -> void:
	await BackendSession.esperar_drenaje_sync_pendiente()


# --- Feedback UI --------------------------------------------------------------


## Conecta señales de sync para UI: POST legacy ([param al_ok], [param al_fallo])
## y batch ([param al_pendientes_terminado] con `(synced_count, failed_count)`).
static func conectar_feedback_sincronizacion(
	al_ok: Callable,
	al_fallo: Callable,
	al_pendientes_terminado: Callable = Callable()
) -> void:
	_conectar_senales_post_legacy(al_ok, al_fallo)
	if al_pendientes_terminado.is_valid():
		_conectar_pendientes_terminado(al_pendientes_terminado)


## Desconecta callbacks registrados con [method conectar_feedback_sincronizacion].
static func desconectar_feedback_sincronizacion(
	al_ok: Callable,
	al_fallo: Callable,
	al_pendientes_terminado: Callable = Callable()
) -> void:
	_desconectar_senales_post_legacy(al_ok, al_fallo)
	if al_pendientes_terminado.is_valid():
		_desconectar_pendientes_terminado(al_pendientes_terminado)


## Escucha [i]pending_sync_finished[/i] una sola vez (p. ej. botón "Guardar ahora" del perfil).
static func conectar_feedback_sincronizacion_one_shot(al_pendientes_terminado: Callable) -> void:
	if BackendSession.pending_sync_finished.is_connected(al_pendientes_terminado):
		return
	BackendSession.pending_sync_finished.connect(al_pendientes_terminado, CONNECT_ONE_SHOT)


## Tras encolar: si el batch ya terminó, invoca [param al_pendientes_terminado] con éxito;
## si quedan ítems pendientes, dispara [method reintentar_pendientes].
static func evaluar_sync_inicial_tras_encolado(al_pendientes_terminado: Callable) -> void:
	if not puede_sincronizar():
		return
	if esta_sincronizando_pendientes():
		return
	if LocalSyncQueue.contar_pendientes() == 0:
		if al_pendientes_terminado.is_valid():
			al_pendientes_terminado.call(1, 0)
	else:
		reintentar_pendientes()


## True si el batch tuvo éxito o no había nada pendiente al evaluar.
static func batch_sync_fue_exitoso(synced_count: int, failed_count: int) -> bool:
	return synced_count > 0 or (
		synced_count == 0 and failed_count == 0 and LocalSyncQueue.contar_pendientes() == 0
	)


## Mensaje corto para pantallas de finalización de partida.
static func mensaje_resultado_batch(synced_count: int, failed_count: int) -> String:
	if batch_sync_fue_exitoso(synced_count, failed_count):
		return mensaje_sync_exitosa()
	return mensaje_sync_pendiente()


## Mensaje detallado para overlay de perfil tras "Guardar ahora".
static func mensaje_resultado_batch_perfil(synced_count: int, failed_count: int) -> String:
	if failed_count == 0:
		return "Todo tu progreso fue actualizado ✓"
	if synced_count > 0:
		return "%d partidas sincronizadas, %d no pudieron" % [synced_count, failed_count]
	return "No se pudo sincronizar. Reintentá más tarde."


# --- Mensajes fijos -----------------------------------------------------------


static func mensaje_guardado_local() -> String:
	return "Guardado localmente"


static func mensaje_sincronizando() -> String:
	return "Sincronizando..."


static func mensaje_sync_exitosa() -> String:
	return "Sincronizado con tu cuenta"


static func mensaje_sync_pendiente() -> String:
	return "Sin conexión: se sincronizará más tarde"


static func mensaje_error(resultado: Dictionary) -> String:
	return AuthApi.mensaje_error(resultado, "No se pudo sincronizar el progreso.")


# --- Internos ---------------------------------------------------------------


static func _conectar_senales_post_legacy(al_ok: Callable, al_fallo: Callable) -> void:
	if not BackendSession.sync_succeeded.is_connected(al_ok):
		BackendSession.sync_succeeded.connect(al_ok)
	if not BackendSession.sync_failed.is_connected(al_fallo):
		BackendSession.sync_failed.connect(al_fallo)


static func _desconectar_senales_post_legacy(al_ok: Callable, al_fallo: Callable) -> void:
	if BackendSession.sync_succeeded.is_connected(al_ok):
		BackendSession.sync_succeeded.disconnect(al_ok)
	if BackendSession.sync_failed.is_connected(al_fallo):
		BackendSession.sync_failed.disconnect(al_fallo)


static func _conectar_pendientes_terminado(callback: Callable) -> void:
	if not BackendSession.pending_sync_finished.is_connected(callback):
		BackendSession.pending_sync_finished.connect(callback)


static func _desconectar_pendientes_terminado(callback: Callable) -> void:
	if BackendSession.pending_sync_finished.is_connected(callback):
		BackendSession.pending_sync_finished.disconnect(callback)
