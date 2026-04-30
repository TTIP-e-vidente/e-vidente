extends RefCounted

const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")
const NodeContentLoaderScript := preload("res://preguntas/NodeContentLoader.gd")

const RUTAS_POR_MODO := {
	NodeContentLoaderScript.MODE_QUIZ_CHOICE: GameSceneRouter.QUESTIONS_SCENE_PATH,
	NodeContentLoaderScript.MODE_DRAG_DROP: "res://niveles/nivel_1/Level.tscn",
}

static func obtener_escena_jugable(modo: String) -> String:
	return str(RUTAS_POR_MODO.get(modo.strip_edges(), "")).strip_edges()
