extends RefCounted
class_name ModalidadRouter

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
	var router: Node = tree.root.get_node_or_null("GameSceneRouter")
	if router != null and router.has_method("ir_a_modo_jugable"):
		router.call("ir_a_modo_jugable", tree, mode)
	else:
		push_error("ModalidadRouter: No se encontro GameSceneRouter en el arbol.")


static func resolver_scene_path(activity: Dictionary) -> String:
	match _resolver_modo(activity):
		MODE_DRAG_DROP:
			return "res://niveles/nivel_1/Level.tscn"
		MODE_QUIZ_CHOICE:
			return "res://preguntas/pregunta.tscn"
		MODE_VINCULACION_CONCEPTOS:
			return "res://vincular/VincularConceptos.tscn"
		MODE_COMPLETAR_PALABRA:
			return COMPLETAR_PALABRA_SCENE_PATH
		_:
			return ""

static func _resolver_modo(activity: Dictionary) -> String:
	var raw_mode: String = str(activity.get("mode", "")).strip_edges()
	return _normalizar_modo(raw_mode)


## Versión pública de _normalizar_modo para uso externo (e.g. GameSceneRouter).
static func normalizar_modo(raw_mode: String) -> String:
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
