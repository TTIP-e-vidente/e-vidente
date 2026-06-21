class_name LeaderboardOverlayHelper
extends RefCounted

const SincronizadorPartidaScript := preload("res://API/backend/sync/SincronizadorPartida.gd")
const LEADERBOARD_SCENE := preload("res://interface/leaderboard/LeaderboardScene.tscn")
const OVERLAY_NODE_NAME := "LeaderboardSceneOverlay"


static func scope_desde_arbol(arbol: SceneTree) -> String:
	if arbol == null:
		return LeaderboardApi.SCOPE_XP_GLOBAL
	var track := SincronizadorPartidaScript.resolver_restriccion(arbol)
	return RestrictionCodes.scope_leaderboard_desde_juego(track)


static func abrir(arbol: SceneTree, scope: String = LeaderboardApi.SCOPE_XP_GLOBAL) -> void:
	if arbol == null or arbol.root == null:
		return

	var scope_final := scope.strip_edges()
	if scope_final.is_empty():
		scope_final = LeaderboardApi.SCOPE_XP_GLOBAL

	var root := arbol.root
	var existente := root.get_node_or_null(OVERLAY_NODE_NAME)
	if existente != null:
		if existente.has_method("abrir"):
			existente.call("abrir", scope_final)
		return

	var leaderboard := LEADERBOARD_SCENE.instantiate()
	leaderboard.name = OVERLAY_NODE_NAME
	root.add_child(leaderboard)
	if leaderboard.has_method("abrir"):
		leaderboard.call("abrir", scope_final)
