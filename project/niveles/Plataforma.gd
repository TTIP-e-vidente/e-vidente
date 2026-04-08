extends Area2D
class_name Plato

@onready var player_cambiante = $"../PlayerCambiante"
@onready var bien = $Bien
@onready var mal = $Mal

var elementos : Array[LevelItem.Condicion]
var cantAlimentosPos = {}
var cantAlimentosNeg = {}

func _react_food(item):
	if  item.esPositivo:
		cantAlimentosPos[item] = null
		bien.play()
	else:
		cantAlimentosNeg[item] = null
		mal.play()
	player_cambiante.item_en_plato(item)


func restore_positive_item(item) -> void:
	if cantAlimentosPos.has(item):
		return
	cantAlimentosPos[item] = null
	elementos.append_array(item.condiciones)
	player_cambiante.item_en_plato(item)


func has_positive_item(item) -> bool:
	return cantAlimentosPos.has(item)

func _on_area_2d_area_exited(area):
	var item_level = area.get_parent()
	if item_level.esPositivo:
		cantAlimentosPos.erase(item_level)
	else:
		cantAlimentosNeg.erase(item_level)
	player_cambiante.item_sale_plato(item_level)
