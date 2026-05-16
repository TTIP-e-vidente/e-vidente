extends RefCounted
class_name ModeFlow

# Recibe nodo + modalidad, confirma dificultad y abre el minijuego.
# No renderiza UI del mapa ni del nodo. No guarda progreso.

const ModalidadRouter := preload("res://sistemas/ModalidadRouter.gd")
const ReglasDeProgreso := preload("res://nodo/ReglasDeProgresoDeNodo.gd")

signal dificultad_confirmada(sesion: GameSessionData)

const DIFICULTAD_FACIL := 1
const DIFICULTAD_MEDIA := 3
const DIFICULTAD_DIFICIL := 5


func confirmar_dificultad(
	tree: SceneTree,
	map_id: String,
	node_id: String,
	mode_id: String,
	difficulty_id: int
) -> void:
	var sesion := _crear_sesion_de_partida(map_id, node_id, mode_id, difficulty_id)
	dificultad_confirmada.emit(sesion)
	_abrir_escena_del_minijuego(tree, mode_id)


static func niveles_de_dificultad_disponibles() -> Array[int]:
	return [DIFICULTAD_FACIL, DIFICULTAD_MEDIA, DIFICULTAD_DIFICIL]


static func _crear_sesion_de_partida(
	map_id: String,
	node_id: String,
	mode_id: String,
	difficulty_id: int
) -> GameSessionData:
	var exp_base: int = ReglasDeProgreso.obtener_exp_por_dificultad(
		ReglasDeProgreso.dificultad_desde_valor(difficulty_id)
	)
	return GameSessionData.crear(map_id, node_id, mode_id, difficulty_id, exp_base)


static func _abrir_escena_del_minijuego(tree: SceneTree, mode_id: String) -> void:
	if mode_id.is_empty():
		push_error("ModeFlow: mode_id vacío, no se puede abrir el minijuego.")
		return
	ModalidadRouter.abrir_modalidad(tree, {"mode": mode_id})
