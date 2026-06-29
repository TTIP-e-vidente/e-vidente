extends Node2D
class_name MainMenu

const MUSICA_FONDO := "res://assets-sistema/sonidos/simple-relaxing-guitar-loop-60828.mp3"

@onready var jugarb: TextureButton = $MenuBar/Jugar
@onready var opcionesb: TextureButton = $MenuBar/Opciones
@onready var mi_progresob: TextureButton = $MenuBar/MiProgreso
@onready var salirb: TextureButton = $MenuBar/Salir
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@onready var jugar: Label = $MenuBar/Jugar/Label
@onready var opciones: Label = $MenuBar/Opciones/Label
@onready var mi_progreso: Label = $MenuBar/MiProgreso/Label
@onready var salir: Label = $MenuBar/Salir/Label

@onready var jugari: Sprite2D = $MenuBar/Jugar/imagen
@onready var opcionesi:Sprite2D = $MenuBar/Opciones/imagen
@onready var mi_progresoi: Sprite2D = $MenuBar/MiProgreso/imagen
@onready var saliri: Sprite2D = $MenuBar/Salir/imagen

const COMO_JUGAR_PATH := "res://assets-sistema/intro/como-jugar-intro-1.png"
const JUGAR_PATH := "res://assets-sistema/intro/play-intro-1.png"
const MI_PROGRESO_PATH := "res://assets-sistema/perfil/perfil-menu.png"
const SALIR_PATH := "res://assets-sistema/intro/salir-intro-1.png"
const LOGIN_SCENE_PATH := "res://API/Login.tscn"
const PROFILE_SCENE_PATH := "res://API/player/Profile.tscn"
const MAIN_MENU_SCENE_PATH := "res://niveles/intro.tscn"
const MODE_SELECTOR_SCENE_PATH := "res://niveles/selector.tscn"
const OPTIONS_SCENE_PATH := "res://interface/opciones.tscn"
const LOGIN_FLOW_GAME := "game"
const LOGIN_FLOW_PROFILE := "profile"
const StreakLossFlowScript := preload("res://niveles/progress/StreakLossFlow.gd")



@onready var buttons: Array[TextureButton] = [
	$MenuBar/Jugar,
	$MenuBar/Opciones,
	$MenuBar/MiProgreso,
	$MenuBar/Salir,
]

var _login_overlay: Control = null
var _login_canvas_layer: CanvasLayer = null
var _login_flow: String = LOGIN_FLOW_GAME
var _profile_overlay: Control = null
var _profile_canvas_layer: CanvasLayer = null


func _ready() -> void:
	jugarb.modulate = Color("#42785e")
	GameSceneRouter.request_initial_scene_preload()
	_reproducir_musica_fondo()
	jugar.text = "Jugar"
	mi_progreso.text = "Mi progreso"
	opciones.text = "Cómo jugar?"
	salir.text = "Salir"
	jugari.texture = load(JUGAR_PATH) as Texture2D
	opcionesi.texture = load(COMO_JUGAR_PATH) as Texture2D
	mi_progresoi.texture = load(MI_PROGRESO_PATH) as Texture2D
	saliri.texture = load(SALIR_PATH) as Texture2D
	BackendSession.session_expired.connect(_on_sesion_expirada)
	if not BackendSession.online_progress_synced.is_connected(_on_progreso_online_sincronizado):
		BackendSession.online_progress_synced.connect(_on_progreso_online_sincronizado)
	call_deferred("_mostrar_perdida_racha_si_corresponde")
	call_deferred("_procesar_retorno_verificacion_mail")
	call_deferred("_procesar_deep_link_leaderboard")
	animated_sprite_2d.play("intro")

func _procesar_deep_link_leaderboard() -> void:
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)


func _on_jugar_presionado() -> void:
	if AuthApi.esta_logueado():
		var resultado := await AuthApi.cargar_datos_online()
		if resultado.get("status", 0) == 401:
			_mostrar_login()
			return
		_continuar_a_juego()
		return
	_mostrar_login()


func _continuar_a_juego() -> void:
	EmailVerificationBridge.habilitar_aviso_mail()
	GameSceneRouter.transicionar_a_escena(_abrir_modo_selector())


func _mostrar_login() -> void:
	_login_flow = LOGIN_FLOW_GAME
	_instanciar_login_overlay()


func _mostrar_login_para_profile() -> void:
	_login_flow = LOGIN_FLOW_PROFILE
	_instanciar_login_overlay()


func _instanciar_login_overlay() -> void:
	if is_instance_valid(_login_overlay):
		_login_overlay.show()
		return
	var login_scene: PackedScene = load(LOGIN_SCENE_PATH) as PackedScene
	if login_scene == null:
		push_error("MainMenu: no se pudo cargar Login.tscn")
		if _login_flow == LOGIN_FLOW_GAME:
			_continuar_a_juego()
		return
	_login_overlay = login_scene.instantiate() as Control
	if _login_overlay == null:
		push_error("MainMenu: Login.tscn no tiene root Control")
		if _login_flow == LOGIN_FLOW_GAME:
			_continuar_a_juego()
		return
	# CanvasLayer garantiza que el overlay ocupe la pantalla completa
	# independientemente del viewport transform del Node2D padre.
	_login_canvas_layer = CanvasLayer.new()
	_login_canvas_layer.layer = 10
	add_child(_login_canvas_layer)
	_login_canvas_layer.add_child(_login_overlay)
	_login_overlay.connect("login_completed", Callable(self, "_on_login_completado"))
	_login_overlay.connect("play_offline_requested", Callable(self, "_on_jugar_offline_solicitado"))
	_login_overlay.connect(
		"verificacion_escena_solicitada",
		Callable(self, "_on_login_verificacion_escena_solicitada")
	)


func _on_login_completado() -> void:
	var current_flow := _login_flow
	_cerrar_login()
	await _mostrar_perdida_racha_si_corresponde()
	EmailVerificationBridge.refrescar_nudge_global()
	LeaderboardDeepLinkBridge.procesar_en_escena_actual(self)
	if current_flow == LOGIN_FLOW_PROFILE:
		_mostrar_perfil()
		return
	_continuar_a_juego()


func _on_jugar_offline_solicitado() -> void:
	var current_flow := _login_flow
	_cerrar_login()
	if current_flow == LOGIN_FLOW_PROFILE:
		return
	if AuthApi.esta_logueado():
		await AuthApi.cerrar_sesion()
	SaveManager.activar_modo_invitado_para_juego()
	_continuar_a_juego()


func _cerrar_login() -> void:
	if is_instance_valid(_login_canvas_layer):
		_login_canvas_layer.queue_free()
	_login_canvas_layer = null
	_login_overlay = null
	_login_flow = LOGIN_FLOW_GAME


func _on_mi_progreso_pressed() -> void:
	if AuthApi.esta_logueado():
		_mostrar_perfil()
		return
	_mostrar_login_para_profile()


func _mostrar_perfil() -> void:
	if is_instance_valid(_profile_overlay):
		_profile_overlay.show()
		return
	var profile_scene: PackedScene = load(PROFILE_SCENE_PATH) as PackedScene
	if profile_scene == null:
		push_error("MainMenu: no se pudo cargar Profile.tscn")
		return
	_profile_overlay = profile_scene.instantiate() as Control
	if _profile_overlay == null:
		push_error("MainMenu: Profile.tscn no tiene root Control")
		return
	_profile_canvas_layer = CanvasLayer.new()
	_profile_canvas_layer.layer = 10
	add_child(_profile_canvas_layer)
	_profile_canvas_layer.add_child(_profile_overlay)
	_profile_overlay.connect("close_requested", Callable(self, "_cerrar_profile"))


func _cerrar_profile() -> void:
	if is_instance_valid(_profile_canvas_layer):
		_profile_canvas_layer.queue_free()
	_profile_canvas_layer = null
	_profile_overlay = null


func _on_opciones_pressed() -> void:
	GameSceneRouter.transicionar_a_escena(_abrir_opciones_menu())


func _on_salir_pressed() -> void:
	get_tree().quit()


func _reproducir_musica_fondo() -> void:
	MusicManager.reproducir_musica(MUSICA_FONDO)


func _abrir_modo_selector() -> String:
	return MODE_SELECTOR_SCENE_PATH


func _on_sesion_expirada() -> void:
	print("[MainMenu] Sesión expirada — redirigiendo a login")
	_mostrar_login()


func _abrir_opciones_menu() -> String:
	return OPTIONS_SCENE_PATH


func _mostrar_perdida_racha_si_corresponde() -> void:
	await StreakLossFlowScript.mostrar_si_corresponde(self)
	EmailVerificationBridge.refrescar_nudge_global()


func _on_progreso_online_sincronizado(_user: Dictionary) -> void:
	if is_instance_valid(_login_overlay):
		return
	await _mostrar_perdida_racha_si_corresponde()


func _on_login_verificacion_escena_solicitada(es_registro: bool, result: Dictionary) -> void:
	_cerrar_login()
	var after_success := (
		"login_continue_profile"
		if _login_flow == LOGIN_FLOW_PROFILE
		else "login_continue_game"
	)
	var nav := {
		"return_scene": MAIN_MENU_SCENE_PATH,
		"after_success": after_success,
	}
	if es_registro:
		EmailVerificationBridge.iniciar_post_registro(result, nav)
	else:
		EmailVerificationBridge.iniciar_pendiente(false, nav)


func _procesar_retorno_verificacion_mail() -> void:
	EmailVerificationBridge.procesar_retorno_escena(self)
	EmailVerificationBridge.refrescar_nudge_global()
