extends Node
class_name Estado

const LevelScript := preload("res://niveles/nivel_1/Level.gd")
const PlayerCambianteScript := preload("res://niveles/PlayerCambiante.gd")

@export var level: LevelScript
@export var player_cambiante: PlayerCambianteScript
@export var animation_name : String 
@export var entra_item_positivo: Node 
@export var entra_item_negativo: Node 
@export var sale_item_positivo: Node 
@export var sale_item_negativo: Node 

func entra_item_plato(item, player):
	if !item.esPositivo:
		if entra_item_negativo : 
			player.abstract_state = entra_item_negativo 
	else:
		if entra_item_positivo :
			player.abstract_state = entra_item_positivo 
	if condiciones_de_victoria(player):
		level._victory()
		animation_name = "recontento"
		player.hambre.hide()

func sale_item_plato(item, player):
	if !item.esPositivo:
		if sale_item_negativo : 
			player.abstract_state = sale_item_negativo 
	else:
		if sale_item_positivo :
			player.abstract_state = sale_item_positivo 
	if condiciones_de_victoria(player):
		level._victory()
		animation_name = "recontento"
		player.hambre.hide()
		
		
func aplicar_animacion(): 
	player_cambiante.current_animation = animation_name

func condiciones_de_victoria(player) : 
	return (player.manager_level.level_resource.cantidadPositivos) == player.plato.cantAlimentosPos.keys().size() && player.plato.cantAlimentosNeg.is_empty() 
