extends Sprite2D
class_name PlayerCambiante

const LevelItemScript := preload("res://resources/level_item.gd")

@onready var hambre = $hambre
@onready var anim = $AnimatedSprite2D
@onready var plato = $"../Plato"
@onready var adelante = $"../Adelante"
@onready var ensenanza = $"../Ensenanza"
var tipo: int
var _current_animation := "cagadodehambre"
var current_animation = "cagadodehambre" : 
	set(value):
		_current_animation = value
		if anim != null:
			anim.play(_current_animation)
	get:
		return _current_animation
var _abstract_state = null
var abstract_state = null : 
	set(new_state):
		_abstract_state = new_state
		if _abstract_state != null:
			_abstract_state.aplicar_animacion()
	get:
		return _abstract_state
@onready var sentir_hambre = $AbstractState/SentirHambre
@onready var manager_level = $"../ManagerLevel"

func _ready():
	tipo = LevelItemScript.Condicion.CELIACO
	abstract_state = sentir_hambre
	anim.play(current_animation)

func item_en_plato(item):
	abstract_state.entra_item_plato(item, self)
	if item.esPositivo: 
		current_animation = "resonrison"
	else : 
		current_animation = "retriston"
	
func item_sale_plato(item):
	abstract_state.sale_item_plato(item, self)


func prepare_for_next_run() -> void:
	hambre.show()
	abstract_state = sentir_hambre
	current_animation = "cagadodehambre"


func _on_animated_sprite_2d_animation_finished():
	abstract_state.aplicar_animacion()
