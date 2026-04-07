extends Node2D
class_name Item_level

@onready var sprite_2d = $Sprite2D
@onready var area_2d = $Area2D
var condiciones : Array[LevelItem.Condicion]
var body_ref 
var plato 
var offset: Vector2
var initialPos: Vector2
var esPositivo = true
var draggable = false
var categoria 
var is_inside_droppable = false
var info: Texture2D
var textSprite: Texture2D
var item_resource_path := ""
var save_instance_id := ""

func setup(level_item: LevelItem, superficie, is_positive: bool, instance_id: String = ""):
	textSprite = level_item.sprite
	$Sprite2D.texture = textSprite
	condiciones = level_item.condiciones.duplicate()
	plato = superficie
	esPositivo = is_positive
	info = level_item.info
	categoria = level_item.categoria
	item_resource_path = level_item.resource_path
	save_instance_id = instance_id.strip_edges()
	if save_instance_id.is_empty():
		save_instance_id = item_resource_path.get_file().get_basename()

func show_info():
	$Sprite2D.texture = info
	
func show_texture():
	$Sprite2D.texture = textSprite


func set_home_position(target_position: Vector2) -> void:
	global_position = target_position
	initialPos = target_position


func restore_to_plate(target_position: Vector2) -> void:
	set_home_position(target_position)
	body_ref = plato
	is_inside_droppable = true

func _process(_delta):
	if draggable:
		if Input.is_action_just_pressed("click"):
			initialPos = global_position
			offset = get_global_mouse_position() - global_position
			Global.is_dragging = self
		if Input.is_action_pressed("click") && Global.is_dragging == self:
			global_position = get_global_mouse_position() - offset
		elif Input.is_action_just_released("click") && Global.is_dragging == self:
			Global.is_dragging = null
			var tween = get_tree().create_tween()
			if is_inside_droppable and is_instance_valid(body_ref):
				tween.tween_property(self, "global_position", get_global_mouse_position(), 0.5).set_ease(Tween.EASE_OUT)
				if body_ref == plato:
					plato._react_food(self)
			else:
				tween.tween_property(self, "global_position", initialPos, 0.5).set_ease(Tween.EASE_OUT)

func _handle_droppable_enter(target):
	if target == null or !target.is_in_group("droppable"):
		return
	is_inside_droppable = true
	body_ref = target
	if target == plato:
		plato.elementos.append_array(condiciones)

func _handle_droppable_exit(target):
	if target == null or !target.is_in_group("droppable"):
		return
	if target == plato:
		condiciones.map(func(cond): plato.elementos.erase(cond))
	if target == body_ref:
		body_ref = null
		is_inside_droppable = false

func _on_area_2d_body_entered(body):
	_handle_droppable_enter(body)

func _on_area_2d_body_exited(body):
	_handle_droppable_exit(body)

func _on_area_2d_area_entered(area):
	_handle_droppable_enter(area)

func _on_area_2d_area_exited(area):
	_handle_droppable_exit(area)

func _on_area_2d_mouse_entered():
	if !Global.is_dragging:
		draggable = true
		scale = Vector2(1.2, 1.2)

func _on_area_2d_mouse_exited():
	if !Global.is_dragging:
		draggable = false
		scale = Vector2(1,1)
