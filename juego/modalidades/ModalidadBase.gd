extends RefCounted
class_name ModalidadBase


## Inicializa la modalidad con los datos de la actividad del JSON.
func configurar_actividad(_datos: Dictionary) -> void:
	pass


## Devuelve el resultado del mini juego una vez terminado.
func obtener_resultado() -> ResultadoDeMiniJuego:
	return ResultadoDeMiniJuego.new()


## Limpia el estado interno antes de liberar la modalidad.
func finalizar_modalidad() -> void:
	pass
