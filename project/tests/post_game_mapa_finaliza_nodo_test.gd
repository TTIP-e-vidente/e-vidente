extends SceneTree

const ContextoFinalizacionDeJuegoScript := preload(
	"res://niveles/progress/ContextoFinalizacionDeJuego.gd"
)
const PostGameFlowControllerScript := preload(
	"res://niveles/progress/PostGameFlowController.gd"
)

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var contexto: Dictionary = ContextoFinalizacionDeJuegoScript.construir(
		"level",
		"celiaquia",
		1,
		27,
		true,
		true,
		"receta_1_desayuno",
		"res://mapas/MapScene.tscn",
		"post_game_mapa_finaliza_nodo_test"
	)
	var estado: Dictionary = PostGameFlowControllerScript.build_post_game_flow_state(
		{"current_count": 1, "last_activity_day": Time.get_date_string_from_system(false)},
		{"current_count": 1, "last_activity_day": Time.get_date_string_from_system(false)},
		contexto,
		{}
	)
	var paso: String = PostGameFlowControllerScript.resolve_post_teaching_step(estado, true)
	var target: Dictionary = PostGameFlowControllerScript.resolve_post_teaching_target(estado, paso)
	_assert(paso == "fallback", "Un nodo de mapa terminado debe volver al mapa, no abrir otro nodo.")
	_assert(str(target.get("type", "")) == "map", "El fallback de mapa debe ser target type=map.")
	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("POST GAME MAPA FINALIZA NODO TEST FAILED: %s" % mensaje)
