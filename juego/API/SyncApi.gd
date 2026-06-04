class_name SyncApi
extends RefCounted

const AdaptadorSyncPartidaScript := preload(
	"res://API/backend/sync/RunSummarySyncAdapter.gd"
)


static func puede_sincronizar() -> bool:
	return AuthApi.esta_logueado()


static func guardar_partida_en_servidor(resumen_partida: Dictionary) -> Dictionary:
	return await BackendSession.guardar_progreso_online(resumen_partida)


static func sincronizar_partida_terminada(
		tree: SceneTree, resultado: Dictionary, stats: Dictionary) -> void:
	AdaptadorSyncPartidaScript.sincronizar_post_partida(tree, resultado, stats)


static func reintentar_pendientes() -> void:
	BackendSession.reintentar_sync_pendiente()


static func conectar_senales_sincronizacion(al_ok: Callable, al_fallo: Callable) -> void:
	if not BackendSession.sync_succeeded.is_connected(al_ok):
		BackendSession.sync_succeeded.connect(al_ok)
	if not BackendSession.sync_failed.is_connected(al_fallo):
		BackendSession.sync_failed.connect(al_fallo)


static func desconectar_senales_sincronizacion(al_ok: Callable, al_fallo: Callable) -> void:
	if BackendSession.sync_succeeded.is_connected(al_ok):
		BackendSession.sync_succeeded.disconnect(al_ok)
	if BackendSession.sync_failed.is_connected(al_fallo):
		BackendSession.sync_failed.disconnect(al_fallo)


## Alias legacy por renombrado gradual.
static func conectar_senales(al_ok: Callable, al_fallo: Callable) -> void:
	conectar_senales_sincronizacion(al_ok, al_fallo)


static func desconectar_senales(al_ok: Callable, al_fallo: Callable) -> void:
	desconectar_senales_sincronizacion(al_ok, al_fallo)


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
