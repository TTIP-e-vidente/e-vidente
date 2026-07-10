extends SceneTree

const INTRO_SCENE := "res://niveles/intro.tscn"
const LOGIN_BUTTON_PATH := (
	"FormScroll/FormCenter/FormMargin/VBoxContainer/ButtonPlayOffline"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var packed := load(INTRO_SCENE) as PackedScene
	if packed == null:
		_fail("No se pudo cargar intro.tscn")
		return

	var intro := packed.instantiate()
	root.add_child(intro)
	await process_frame
	await process_frame

	intro.call("_on_jugar_presionado")
	await process_frame
	await process_frame

	var login := _buscar_login_overlay(intro)
	if login == null:
		_fail("Intro no instanció el overlay de Login al presionar Jugar")
		return

	var boton := login.get_node_or_null(NodePath(LOGIN_BUTTON_PATH)) as Button
	if boton == null:
		_fail("Login overlay sin botón offline en %s" % LOGIN_BUTTON_PATH)
		return

	if not boton.visible:
		_fail("ButtonPlayOffline existe pero no es visible")
		return

	print("[IntroLoginTest] OK: menú → overlay login con botones accesibles.")
	quit(0)


func _buscar_login_overlay(nodo: Node) -> Node:
	for child in nodo.get_children():
		if child is CanvasLayer:
			for layer_child in child.get_children():
				if layer_child.has_signal("play_offline_requested"):
					return layer_child
		var found := _buscar_login_overlay(child)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error("[IntroLoginTest] %s" % message)
	quit(1)
