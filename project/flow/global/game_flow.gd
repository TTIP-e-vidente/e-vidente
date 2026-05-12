extends RefCounted
class_name GameFlow

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

enum Etapa { SPLASH, MENU, MAPA, NODO, MODO, MINIJUEGO, RESULTADOS }

var _etapa_actual: Etapa = Etapa.SPLASH


func ir_al_mapa(tree: SceneTree) -> void:
	_etapa_actual = Etapa.MAPA
	GameSceneRouter.go_to_map(tree)


func ir_al_menu(tree: SceneTree) -> void:
	_etapa_actual = Etapa.MENU
	GameSceneRouter.go_to_main_menu(tree)


func ir_al_splash(tree: SceneTree) -> void:
	_etapa_actual = Etapa.SPLASH
	GameSceneRouter.go_to_splash(tree)


func registrar_nodo_activo() -> void:
	_etapa_actual = Etapa.NODO


func registrar_modo_activo() -> void:
	_etapa_actual = Etapa.MODO


func registrar_minijuego_activo() -> void:
	_etapa_actual = Etapa.MINIJUEGO


func registrar_resultados_activos() -> void:
	_etapa_actual = Etapa.RESULTADOS


func obtener_etapa_actual() -> Etapa:
	return _etapa_actual
