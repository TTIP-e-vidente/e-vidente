extends SceneTree

const LOGIN_SCENE := "res://API/Login.tscn"

const NODE_PATHS: Array[String] = [
	"FormScroll",
	"FormScroll/FormCenter",
	"FormScroll/FormCenter/FormMargin",
	"FormScroll/FormCenter/FormMargin/VBoxContainer",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LabelTitle",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LineEditUsernameOrMail",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LineEditPassword",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LineEditRegisterName",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LineEditRegisterMail",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LabelRegisterMailHint",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LineEditRegisterBirthDate",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LabelRegisterBirthHint",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/ButtonSubmit",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/ButtonSwitchMode",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/ButtonPlayOffline",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/ButtonRetryConnection",
	"FormScroll/FormCenter/FormMargin/VBoxContainer/LabelStatus",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var packed := load(LOGIN_SCENE) as PackedScene
	if packed == null:
		_fail("No se pudo cargar Login.tscn")
		return

	var login := packed.instantiate()
	if login == null:
		_fail("Login.tscn no instancia un nodo raíz")
		return

	root.add_child(login)
	await process_frame
	await process_frame

	for path in NODE_PATHS:
		var node := login.get_node_or_null(NodePath(path))
		if node == null:
			_fail("Nodo faltante en Login.tscn: %s" % path)
			return

	var vbox := login.get_node("FormScroll/FormCenter/FormMargin/VBoxContainer") as VBoxContainer
	if vbox.get_child_count() < 12:
		_fail(
			"VBoxContainer del login tiene %d hijos; se esperaban al menos 12"
			% vbox.get_child_count()
		)
		return

	print("[LoginSceneTest] OK: escena Login.tscn instancia todos los nodos del formulario.")
	quit(0)


func _fail(message: String) -> void:
	push_error("[LoginSceneTest] %s" % message)
	quit(1)
