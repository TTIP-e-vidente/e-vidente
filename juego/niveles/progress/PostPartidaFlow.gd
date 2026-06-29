class_name PostPartidaFlow
extends RefCounted

# Orquestador del flujo post-partida (después de completar un nodo del mapa).
#
# Secuencia:
#   1. finalizacion_partida  → solo stats (EXP, precisión, tiempo) + Continuar
#   2. ranking_post_partida  → ranking, preferencia invitado y "Continuar al mapa"
#   3. MapScene              → el jugador sigue explorando
#
# Reglas de negocio:
#   - Invitado: puede ver ranking en solo lectura; no suma puntos.
#   - Logueado: ve su puesto y progreso competitivo.
#   - Invitado con preferencia activa: salta la escena 2 y va directo al mapa.
#
# Las escenas (.gd de mapas/) solo conectan botones y dibujan UI.
# Toda la lógica compartida vive acá para que sea fácil de leer y testear.


const SincronizadorPartidaScript := preload("res://API/backend/sync/SincronizadorPartida.gd")


static func resolver_scope_desde_arbol(tree: SceneTree) -> String:
	return RestrictionCodes.scope_leaderboard_desde_juego(
		SincronizadorPartidaScript.resolver_restriccion(tree)
	)


static func usa_layout_salto_ranking() -> bool:
	return not AuthApi.esta_logueado() and SaveManager.omitir_ranking_post_partida_invitado()


static func texto_boton_dashboard() -> String:
	return LeaderboardFormat.texto_continuar_dashboard()


static func continuar_desde_dashboard(tree: SceneTree) -> void:
	if usa_layout_salto_ranking():
		finalizar_flujo_y_ir_al_mapa(tree)
		return
	ir_a_ranking(tree)


static func persistir_preferencia_omitir_ranking(omitir: bool) -> void:
	if AuthApi.esta_logueado():
		return
	SaveManager.guardar_omitir_ranking_post_partida_invitado(omitir)


static func prefetch_ranking_si_corresponde(tree: SceneTree) -> void:
	if usa_layout_salto_ranking():
		return
	var scope := resolver_scope_desde_arbol(tree)
	if AuthApi.esta_logueado():
		LeaderboardService.prefetch_resumen_competitivo(scope)
	else:
		LeaderboardService.prefetch(scope)


static func ir_a_ranking(tree: SceneTree) -> void:
	GameSceneRouter.ir_a_ranking_post_partida(tree)


static func finalizar_flujo_y_ir_al_mapa(tree: SceneTree) -> void:
	Global.obtener_y_limpiar_ultima_finalizacion()
	GameSceneRouter.ir_al_mapa(tree)


static func cargar_ranking_en_card(
	card: RankingResumenPostPartida,
	tree: SceneTree
) -> String:
	if not is_instance_valid(card):
		return LeaderboardApi.SCOPE_XP_GLOBAL

	var scope := resolver_scope_desde_arbol(tree)

	if not AuthApi.esta_logueado():
		card.mostrar_modo_invitado(scope)
		await card.cargar_tabla_invitado()
		return scope

	card.mostrar_estado_carga()

	var inicio_carga := Time.get_unix_time_from_system()
	var puesto_antes := LeaderboardService.consumir_puesto_antes_partida(scope)
	if puesto_antes <= CelebracionSubidaRanking.PUESTO_NO_REGISTRADO:
		puesto_antes = LeaderboardService.obtener_puesto_desde_resumen_cache(scope)
	if puesto_antes <= CelebracionSubidaRanking.PUESTO_NO_REGISTRADO:
		var resultado_previo: Variant = await LeaderboardService.cargar_resumen_competitivo(
			false,
			scope
		)
		if resultado_previo is Dictionary \
		and bool((resultado_previo as Dictionary).get("ok", false)):
			puesto_antes = LeaderboardService.obtener_puesto_desde_resumen_cache(scope)

	LeaderboardService.invalidar_cache(scope)
	await LeaderboardService.esperar_refresh_scope(scope, inicio_carga - 45.0, 3.0)

	var resultado_raw: Variant = await LeaderboardService.cargar_resumen_competitivo(true, scope)
	if not is_instance_valid(card):
		return scope
	if not resultado_raw is Dictionary:
		await _mostrar_invitado_y_tabla(card, scope)
		return scope

	var resultado := resultado_raw as Dictionary
	if not resultado.get("ok", false):
		await _mostrar_invitado_y_tabla(card, scope)
		return scope

	var datos: Variant = resultado.get("data", resultado)
	if datos is Dictionary and bool((datos as Dictionary).get("available", false)):
		card.mostrar_desde_datos(datos as Dictionary, puesto_antes)
		LeaderboardService.marcar_refresco_tras_partida(scope)
	else:
		await _mostrar_invitado_y_tabla(card, scope)

	return scope


static func _mostrar_invitado_y_tabla(card: RankingResumenPostPartida, scope: String) -> void:
	if not is_instance_valid(card):
		return
	card.mostrar_modo_invitado(scope)
	await card.cargar_tabla_invitado()
