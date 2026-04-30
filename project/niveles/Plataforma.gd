extends Area2D
class_name Plato

@export var player_cambiante_path: NodePath = NodePath("../PlayerCambiante")

@onready var player_cambiante: Node = get_node_or_null(player_cambiante_path)
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
	_notificar_item_en_plato(item)


func restaurar_positivo_elemento(item) -> void:
	if cantAlimentosPos.has(item):
		return
	cantAlimentosPos[item] = null
	elementos.append_array(item.condiciones)
	_notificar_item_en_plato(item)


func tiene_positivo_elemento(item) -> bool:
	return cantAlimentosPos.has(item)

func _on_area_2d_area_salido(area):
	var item_level = area.get_parent()
	if item_level.esPositivo:
		cantAlimentosPos.erase(item_level)
	else:
		cantAlimentosNeg.erase(item_level)
	_notificar_item_fuera_del_plato(item_level)


func _notificar_item_en_plato(item) -> void:
	if player_cambiante == null:
		push_warning("PlayerCambiante no encontrado en Plato.")
		return
	if not player_cambiante.has_method("elemento_en_plato"):
		return
	player_cambiante.call("elemento_en_plato", item)


func _notificar_item_fuera_del_plato(item) -> void:
	if player_cambiante == null:
		push_warning("PlayerCambiante no encontrado en Plato.")
		return
	if not player_cambiante.has_method("elemento_sale_plato"):
		return
	player_cambiante.call("elemento_sale_plato", item)
