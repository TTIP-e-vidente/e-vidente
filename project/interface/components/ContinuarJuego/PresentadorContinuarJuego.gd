extends RefCounted


static func mostrar(
	continuar_juego: Node,
	hay_siguiente_juego: bool,
	segundos: int = 5
) -> void:
	if continuar_juego == null:
		return
	if hay_siguiente_juego:
		continuar_juego.call("mostrar_para_siguiente_juego", segundos)
		return
	continuar_juego.call("mostrar_para_finalizar", segundos)


static func ocultar(continuar_juego: Node) -> void:
	if continuar_juego != null and continuar_juego.has_method("ocultar"):
		continuar_juego.call("ocultar")