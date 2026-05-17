extends RefCounted
class_name ModalidadRouter

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

const MODE_DRAG_DROP := "drag_drop"
const MODE_QUIZ_CHOICE := "quiz_choice"
const MODE_VINCULACION_CONCEPTOS := "vinculacion_conceptos"
const MODE_COMPLETAR_PALABRA := "completar_palabra"

const COMPLETAR_PALABRA_SCENE_PATH := "res://completar/completar_palabra.tscn"


static func abrir_modalidad(tree: SceneTree, activity: Dictionary) -> void:
	var mode: String = _resolver_modo(activity)
	if mode.is_empty():
		push_error(
			"ModalidadRouter: mode invalido en activity: %s" % JSON.stringify(activity)
		)
		return
	GameSceneRouter.ir_a_modo_jugable(tree, mode)


static func resolver_scene_path(activity: Dictionary) -> String:
	match _resolver_modo(activity):
		MODE_DRAG_DROP:
			return GameSceneRouter.LEVEL_SCENE_PATH
		MODE_QUIZ_CHOICE:
			return GameSceneRouter.QUESTIONS_SCENE_PATH
		MODE_VINCULACION_CONCEPTOS:
			return GameSceneRouter.VINCULACION_CONCEPTOS_SCENE_PATH
		MODE_COMPLETAR_PALABRA:
			return COMPLETAR_PALABRA_SCENE_PATH
		_:
			return ""

static func _resolver_modo(activity: Dictionary) -> String:
	var raw_mode: String = str(activity.get("mode", "")).strip_edges()
	return _normalizar_modo(raw_mode)


static func _normalizar_modo(raw_mode: String) -> String:
	match raw_mode:
		"drag_drop", "drag", "drag_food":
			return MODE_DRAG_DROP
		"quiz_choice", "quiz":
			return MODE_QUIZ_CHOICE
		"vinculacion_conceptos", "match":
			return MODE_VINCULACION_CONCEPTOS
		"completar_palabra":
			return MODE_COMPLETAR_PALABRA
		_:
			return ""
