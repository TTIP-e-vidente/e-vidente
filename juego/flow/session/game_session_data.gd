extends Resource
class_name GameSessionData

# Datos necesarios para iniciar una partida.
# Se crea en NodoRuntime al abrir un nodo y se guarda en Global.

@export var map_id: String = ""
@export var node_id: String = ""
@export var mode_id: String = ""
@export var difficulty_id: int = 1
@export var exp_base: int = 0
@export var payload: Dictionary = {}


static func crear(
	p_map_id: String,
	p_node_id: String,
	p_mode_id: String,
	p_difficulty_id: int,
	p_exp_base: int = 0,
	p_payload: Dictionary = {}
) -> GameSessionData:
	var sesion := GameSessionData.new()
	sesion.map_id = p_map_id
	sesion.node_id = p_node_id
	sesion.mode_id = p_mode_id
	sesion.difficulty_id = p_difficulty_id
	sesion.exp_base = p_exp_base
	sesion.payload = p_payload.duplicate()
	return sesion


func a_diccionario() -> Dictionary:
	return {
		"map_id": map_id,
		"node_id": node_id,
		"mode_id": mode_id,
		"difficulty_id": difficulty_id,
		"exp_base": exp_base,
		"payload": payload.duplicate(),
	}
