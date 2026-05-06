extends "res://mapas/logica/ContinuidadDePartidaDeNodo.gd"

const ContinuidadDePartidaDeNodoScript := preload("res://mapas/logica/ContinuidadDePartidaDeNodo.gd")

static func continuar_o_finalizar_partida(
	tree: SceneTree,
	antes_de_abrir_siguiente_juego: Callable = Callable(),
	al_finalizar_partida: Callable = Callable()
) -> bool:
	return ContinuidadDePartidaDeNodoScript.continuar_o_finalizar_partida(
		tree,
		antes_de_abrir_siguiente_juego,
		al_finalizar_partida
	)


static func hay_siguiente_juego(tree: SceneTree) -> bool:
	return ContinuidadDePartidaDeNodoScript.hay_siguiente_juego(tree)


static func abrir_juego_actual(tree: SceneTree, estado_global: Node = null) -> bool:
	return ContinuidadDePartidaDeNodoScript.abrir_juego_actual(tree, estado_global)
