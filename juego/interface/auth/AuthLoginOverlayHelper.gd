class_name AuthLoginOverlayHelper
extends RefCounted

# Muestra el overlay de Login encima de cualquier escena.
# Usado desde leaderboard, perfil HUD, etc.


const LOGIN_SCENE := preload("res://API/Login.tscn")

const FLUJO_JUEGO := "game"
const FLUJO_PERFIL := "profile"


var _capa_canvas: CanvasLayer = null
var _backdrop: ColorRect = null
var _overlay_login: Control = null
var _nodo_ancla: Node = null
var _flujo_actual: String = FLUJO_JUEGO
var _formulario_terminado: bool = false


func mostrar_y_esperar(nodo_ancla: Node, flujo: String = FLUJO_JUEGO) -> bool:
	if nodo_ancla == null or nodo_ancla.get_tree() == null:
		return false

	_flujo_actual = flujo
	_nodo_ancla = nodo_ancla
	_formulario_terminado = false
	_instalar_overlay()

	if _overlay_login == null:
		return false

	_overlay_login.login_completed.connect(_marcar_formulario_terminado, CONNECT_ONE_SHOT)
	_overlay_login.play_offline_requested.connect(_marcar_formulario_terminado, CONNECT_ONE_SHOT)
	_overlay_login.verificacion_escena_solicitada.connect(_al_solicitar_verificacion_mail, CONNECT_ONE_SHOT)

	while not _formulario_terminado and is_instance_valid(_overlay_login):
		await _nodo_ancla.get_tree().process_frame

	_cerrar_overlay()
	return AuthApi.esta_logueado()


func _marcar_formulario_terminado() -> void:
	_formulario_terminado = true


func _instalar_overlay() -> void:
	if is_instance_valid(_overlay_login):
		if is_instance_valid(_backdrop):
			_backdrop.visible = true
		_overlay_login.show()
		return

	_capa_canvas = CanvasLayer.new()
	_capa_canvas.layer = 95
	_nodo_ancla.add_child(_capa_canvas)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.color = Color(0.11, 0.1, 0.09, 0.58)
	_capa_canvas.add_child(_backdrop)

	_overlay_login = LOGIN_SCENE.instantiate() as Control
	if _overlay_login == null:
		_cerrar_overlay()
		return
	_capa_canvas.add_child(_overlay_login)


func _al_solicitar_verificacion_mail(es_registro: bool, result: Dictionary) -> void:
	var escena_retorno := ""
	if _nodo_ancla != null and _nodo_ancla.get_tree() != null and _nodo_ancla.get_tree().current_scene != null:
		escena_retorno = str(_nodo_ancla.get_tree().current_scene.scene_file_path).strip_edges()

	var despues_del_exito := "login_continue_game"
	if _flujo_actual == FLUJO_PERFIL:
		despues_del_exito = "login_continue_profile"

	var navegacion := {
		"return_scene": escena_retorno,
		"after_success": despues_del_exito,
	}
	if es_registro:
		EmailVerificationBridge.iniciar_post_registro(result, navegacion)
	else:
		EmailVerificationBridge.iniciar_pendiente(false, navegacion)

	_marcar_formulario_terminado()


func _cerrar_overlay() -> void:
	if is_instance_valid(_capa_canvas):
		_capa_canvas.queue_free()
	_capa_canvas = null
	_backdrop = null
	_overlay_login = null
	_nodo_ancla = null
