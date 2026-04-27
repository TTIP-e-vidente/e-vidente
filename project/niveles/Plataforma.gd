extends Area2D
class_name Plato

@onready var player_cambiante = $"../PlayerCambiante"
@onready var bien = $Bien
@onready var mal = $Mal

var elementos: Array[int] = []
var cantAlimentosPos = {}
var cantAlimentosNeg = {}

func reaccionar_comida(item) -> void:
	_reaccionar_comida(item)


func _reaccionar_comida(item):
	if  item.esPositivo:
		cantAlimentosPos[item] = null
		bien.play()
	else:
		cantAlimentosNeg[item] = null
		mal.play()
	player_cambiante.elemento_en_plato(item)


func restaurar_positivo_elemento(item) -> void:
	if cantAlimentosPos.has(item):
		return
	cantAlimentosPos[item] = null
	elementos.append_array(item.condiciones)
	player_cambiante.elemento_en_plato(item)


func tiene_positivo_elemento(item) -> bool:
	return cantAlimentosPos.has(item)

func _on_area_2d_area_salido(area):
	var item_level = area.get_parent()
	if item_level.esPositivo:
		cantAlimentosPos.erase(item_level)
	else:
		cantAlimentosNeg.erase(item_level)
	player_cambiante.elemento_sale_plato(item_level)
