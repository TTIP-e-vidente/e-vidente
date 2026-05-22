extends RefCounted
class_name ResultsFlow

# Normaliza el resultado del minijuego y coordina la vuelta al mapa.
# No renderiza. No arma planes de partida. No contiene reglas del minijuego.

const ResultadoDeNodoScript := preload("res://nodo/ResultadoDeNodo.gd")
const ReglasDeProgreso := preload("res://nodo/ReglasDeProgresoDeNodo.gd")
const GameSceneRouter := preload("res://niveles/GameSceneRouter.gd")

signal volver_al_mapa_solicitado()


func procesar_resultado_de_partida(
	result_data: Dictionary,
	save_manager: Node
) -> ResultadoDeNodo:
	var resultado_de_nodo := ResultadoDeNodoScript.desde_diccionario(result_data)
	# ContinuidadDePartidaDeNodo ya llamó add_exp() antes de llegar aquí.
	# Se acepta save_manager explícito solo como llamada de seguridad adicional.
	_guardar_progreso_local(save_manager)
	return resultado_de_nodo


static func calcular_exp_ganada(exp_base: int, precision_ratio: float) -> int:
	return ReglasDeProgreso.calcular_exp_final(exp_base, precision_ratio)


func volver_al_mapa(_tree: SceneTree) -> void:
	volver_al_mapa_solicitado.emit()
	await TransicionEscenas.change_scene(GameSceneRouter.MAP_SCENE_PATH)


static func _guardar_progreso_local(save_manager: Node) -> void:
	if save_manager == null:
		return
	if save_manager.has_method("guardar_progreso_en_disco"):
		save_manager.guardar_progreso_en_disco()
