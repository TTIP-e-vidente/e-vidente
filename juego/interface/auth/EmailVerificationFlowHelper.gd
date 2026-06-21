extends RefCounted
class_name EmailVerificationFlowHelper

const SCENE_PATH := "res://interface/auth/EmailVerification.tscn"
const META_EVALUACION := "email_verify_evaluacion"
const META_OBLIGATORIO := "email_verify_obligatorio"
const META_RETURN_SCENE := "email_verify_return_scene"
const META_AFTER_SUCCESS := "email_verify_after_success"
const META_OUTCOME := "email_verify_outcome"

static var _waiter_resolved := false
static var _waiter_outcome := "error"


static func reset_waiter() -> void:
	_waiter_resolved = false
	_waiter_outcome = "error"


static func complete_waiter(outcome: String) -> void:
	_waiter_outcome = outcome
	_waiter_resolved = true


static func detectar_escena_actual(contexto: Node) -> String:
	if contexto == null:
		return GameSceneRouter.MAIN_MENU_SCENE_PATH
	var tree := contexto.get_tree()
	if tree == null or tree.current_scene == null:
		return GameSceneRouter.MAIN_MENU_SCENE_PATH
	var path := str(tree.current_scene.scene_file_path).strip_edges()
	if path.is_empty():
		return GameSceneRouter.MAIN_MENU_SCENE_PATH
	return path


static func limpiar_metas_config(root: Window) -> void:
	if root == null:
		return
	for key in [META_EVALUACION, META_OBLIGATORIO, META_RETURN_SCENE]:
		if root.has_meta(key):
			root.remove_meta(key)


static func consumir_retorno(root: Window) -> Dictionary:
	if root == null or not root.has_meta(META_OUTCOME):
		return {}
	var payload := {
		"outcome": str(root.get_meta(META_OUTCOME, "")),
		"after_success": str(root.get_meta(META_AFTER_SUCCESS, "none")),
	}
	root.remove_meta(META_OUTCOME)
	if root.has_meta(META_AFTER_SUCCESS):
		root.remove_meta(META_AFTER_SUCCESS)
	return payload


## Navega a la escena de verificación y espera el resultado.
## Retorna: "completado", "omitido" o "error".
static func mostrar_y_esperar(
		contexto: Node,
		evaluacion: Dictionary,
		requiere_verificacion: bool = false,
		navegacion: Dictionary = {}
) -> String:
	if contexto == null or contexto.get_tree() == null:
		return "error"

	var tree := contexto.get_tree()
	var root := tree.root

	reset_waiter()
	root.set_meta(META_EVALUACION, evaluacion.duplicate(true))
	root.set_meta(META_OBLIGATORIO, requiere_verificacion)

	var return_scene := str(navegacion.get("return_scene", "")).strip_edges()
	if return_scene.is_empty():
		return_scene = detectar_escena_actual(contexto)
	root.set_meta(META_RETURN_SCENE, return_scene)

	var after_success := str(navegacion.get("after_success", "none")).strip_edges()
	if after_success.is_empty():
		after_success = "none"
	root.set_meta(META_AFTER_SUCCESS, after_success)

	if root.has_meta(META_OUTCOME):
		root.remove_meta(META_OUTCOME)

	await TransicionEscenas.cambiar_escena_normal(SCENE_PATH)

	while not _waiter_resolved:
		await tree.process_frame

	return _waiter_outcome
