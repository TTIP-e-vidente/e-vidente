class_name PostPartidaFlow
extends RefCounted

# Orquestador del flujo post-partida (después de completar un nodo del mapa).
#
# Secuencia:
#   1. finalizacion_partida  → solo stats (EXP, precisión, tiempo) + Continuar
#   2. ranking_post_partida  → ranking, preferencia invitado y "Continuar al mapa"
#   3. racha (opcional)      → solo si la racha estaba inactiva y se activo en esta partida
#   4. MapScene              → el jugador sigue explorando
#
# Reglas de negocio:
#   - Invitado: puede ver ranking en solo lectura; no suma puntos.
#   - Logueado: ve su puesto y progreso competitivo.
#   - Invitado con preferencia activa: salta la escena 2 y va directo al mapa
#     (pero igual puede pasar por la escena 3 si corresponde).
#
# Las escenas (.gd de mapas/) solo conectan botones y dibujan UI.
# Toda la lógica compartida vive acá para que sea fácil de leer y testear.

const GameStreakTrackerScript := preload("res://niveles/progress/GameStreakTracker.gd")


static func resolver_scope_desde_arbol(tree: SceneTree) -> String:
	return RestrictionCodes.scope_leaderboard_desde_juego(
		SincronizadorPartida.resolver_restriccion(tree)
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
	var feedback_racha: Dictionary = _resolver_feedback_racha_activada()
	if not feedback_racha.is_empty():
		GameSceneRouter.ir_a_racha(tree, GameSceneRouter.MAP_SCENE_PATH, feedback_racha)
		return
	GameSceneRouter.ir_al_mapa(tree)


## Compara la racha de ANTES de iniciar esta partida (snapshot tomado en
## NodoRuntime.iniciar) contra la racha actual: si estaba inactiva (sin
## importar el motivo — nunca jugo, se vencio, o seguia viva pero pendiente
## de hoy) y ahora quedo activa por esta partida, arma el feedback para
## mostrar "tu racha se activo" en la pantalla de racha, despues del
## leaderboard y antes de volver al mapa.
static func _resolver_feedback_racha_activada() -> Dictionary:
	var previous_streak: Dictionary = Global.obtener_y_limpiar_snapshot_racha_inicio_partida()
	if previous_streak.is_empty():
		return {}

	var previous_vista: Dictionary = GameStreakTrackerScript.modelo_vista(previous_streak)
	if str(previous_vista.get("status_key", "")) == "active_today":
		return {}

	var updated_streak: Dictionary = Global.obtener_estado_racha()
	var updated_vista: Dictionary = GameStreakTrackerScript.modelo_vista(updated_streak)
	if str(updated_vista.get("status_key", "")) != "active_today":
		return {}

	var feedback: Dictionary = GameStreakTrackerScript.construir_feedback(
		previous_streak,
		updated_streak,
		false
	)
	if not bool(feedback.get("should_show", false)):
		return {}
	return feedback


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
