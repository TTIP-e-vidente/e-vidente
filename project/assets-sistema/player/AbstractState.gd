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
	_handle_plate_change(
		item,
		player,
		entra_item_positivo,
		entra_item_negativo
	)

func sale_item_plato(item, player):
	_handle_plate_change(
		item,
		player,
		sale_item_positivo,
		sale_item_negativo
	)
		
		
func aplicar_animacion(): 
	player_cambiante.current_animation = animation_name

func condiciones_de_victoria(player) : 
	return player.manager_level.tiene_completado_actual_corrida()


func _handle_plate_change(item, player, positive_state: Node, negative_state: Node) -> void:
	_apply_state_transition(item, player, positive_state, negative_state)
	if not condiciones_de_victoria(player):
		return
	level.completar_corrida_actual()
	animation_name = "recontento"
	player.hambre.hide()


func _apply_state_transition(item, player, positive_state: Node, negative_state: Node) -> void:
	var next_state: Node = positive_state if item.esPositivo else negative_state
	if next_state != null:
		player.abstract_state = next_state
