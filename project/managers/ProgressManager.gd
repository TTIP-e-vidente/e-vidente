extends Node

var niveles_completados := {}
var capitulos := {
	"celiaquia": 14
}

var capitulos_mostrados := []

signal capitulo_completado(capitulo)

func completar_nivel(capitulo: String, nivel_id: int):
	if not niveles_completados.has(capitulo):
		niveles_completados[capitulo] = []
	
	if nivel_id not in niveles_completados[capitulo]:
		niveles_completados[capitulo].append(nivel_id)

	if capitulo_completo(capitulo) and not ya_mostrado(capitulo):
		emit_signal("capitulo_completado", capitulo)


func capitulo_completo(capitulo: String) -> bool:
	if not niveles_completados.has(capitulo):
		return false
	
	return niveles_completados[capitulo].size() == capitulos[capitulo]

func ya_mostrado(capitulo: String) -> bool:
	return capitulo in capitulos_mostrados

func marcar_mostrado(capitulo: String):
	if not ya_mostrado(capitulo):
		capitulos_mostrados.append(capitulo)
