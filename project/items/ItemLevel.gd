extends Node2D
class_name Item_level

@onready var sprite_2d = $Sprite2D
@onready var area_2d = $Area2D
var condiciones: Array[int] = []
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
var item_visual_resource_path := ""
var item_id := ""
var item_label := ""
var item_feedback := ""
var item_correct_target := ""
var save_instance_id := ""
var interaction_enabled := true
static var is_dragging: Object = null

func setup(level_item, superficie, is_positive: bool, instance_id: String = ""):
	textSprite = level_item.sprite
	$Sprite2D.texture = textSprite
	condiciones = level_item.condiciones.duplicate()
	plato = superficie
	esPositivo = is_positive
	info = level_item.info
	categoria = level_item.categoria
	item_id = str(level_item.runtime_id).strip_edges()
	item_label = str(level_item.runtime_label).strip_edges()
	item_feedback = str(level_item.runtime_feedback).strip_edges()
	item_correct_target = str(level_item.runtime_correct_target).strip_edges()
	item_resource_path = str(level_item.runtime_resource_path).strip_edges()
	if item_resource_path.is_empty():
		item_resource_path = level_item.resource_path
	item_visual_resource_path = str(level_item.runtime_visual_resource_path).strip_edges()
	save_instance_id = item_id
	if save_instance_id.is_empty():
		save_instance_id = instance_id.strip_edges()
	if save_instance_id.is_empty():
		save_instance_id = item_resource_path.get_file().get_basename()
	_reportar_mismatch_si_corresponde()

func show_info():
	$Sprite2D.texture = info
	_reportar_mismatch_si_corresponde()
	
func show_texture():
	$Sprite2D.texture = textSprite
	_reportar_mismatch_si_corresponde()


func set_home_position(target_position: Vector2) -> void:
	global_position = target_position
	initialPos = target_position


func restore_to_plate(target_position: Vector2) -> void:
	set_home_position(target_position)
	body_ref = plato
	is_inside_droppable = true
	print(
		"[ManagerLevelItem] placed id=%s detail=%s"
		% [
			item_id if not item_id.is_empty() else save_instance_id,
			info.resource_path if info != null else "",
		]
	)


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not interaction_enabled and is_dragging == self:
		is_dragging = null
	draggable = false
	scale = Vector2.ONE
	if is_instance_valid(area_2d):
		area_2d.input_pickable = interaction_enabled


func is_interaction_enabled() -> bool:
	return interaction_enabled

func _process(_delta):
	if not interaction_enabled:
		return
	if draggable:
		if Input.is_action_just_pressed("click"):
			initialPos = global_position
			offset = get_global_mouse_position() - global_position
			is_dragging = self
		if Input.is_action_pressed("click") && is_dragging == self:
			global_position = get_global_mouse_position() - offset
		elif Input.is_action_just_released("click") && is_dragging == self:
			is_dragging = null
			var tween = get_tree().create_tween()
			if is_inside_droppable and is_instance_valid(body_ref):
				print(
					"[ARRASTRE] item=",
					save_instance_id if not save_instance_id.is_empty() else item_resource_path,
					" target=",
					body_ref.name,
					" correcto=",
					body_ref == plato and esPositivo
				)
				tween.tween_property(
					self,
					"global_position",
					get_global_mouse_position(),
					0.5
				).set_ease(Tween.EASE_OUT)
				if body_ref == plato:
					print(
						"[ManagerLevelItem] placed id=%s detail=%s"
						% [
							item_id if not item_id.is_empty() else save_instance_id,
							info.resource_path if info != null else "",
						]
					)
					plato.reaccionar_comida(self)
			else:
				print(
					"[ARRASTRE] item=",
					save_instance_id if not save_instance_id.is_empty() else item_resource_path,
					" target=",
					"",
					" correcto=",
					false
				)
				tween.tween_property(
					self,
					"global_position",
					initialPos,
					0.5
				).set_ease(Tween.EASE_OUT)

func _handle_droppable_enter(target):
	if not interaction_enabled:
		return
	if target == null or !target.is_in_group("droppable"):
		return
	is_inside_droppable = true
	body_ref = target
	if target == plato:
		plato.elementos.append_array(condiciones)

func _handle_droppable_exit(target):
	if not interaction_enabled:
		return
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

func _on_area_2d_area_salido(area):
	_handle_droppable_exit(area)

func _on_area_2d_mouse_entered():
	if not interaction_enabled:
		return
	if !is_dragging:
		draggable = true
		scale = Vector2(1.2, 1.2)

func _on_area_2d_mouse_exited():
	if not interaction_enabled:
		return
	if !is_dragging:
		draggable = false
		scale = Vector2(1,1)


func _reportar_mismatch_si_corresponde() -> void:
	if item_id.is_empty():
		return
	var visual_id: String = _normalizar_id_visual(item_visual_resource_path)
	if visual_id.is_empty() and textSprite != null:
		visual_id = _normalizar_id_visual(textSprite.resource_path)
	var logical_id: String = _normalizar_id_visual(item_id)
	if visual_id.is_empty() or logical_id.is_empty() or visual_id == logical_id:
		return
	print("[ItemMismatch] visual_id=%s logical_id=%s" % [visual_id, logical_id])


func _normalizar_id_visual(raw_value: String) -> String:
	var clean := raw_value.strip_edges().get_file().get_basename().to_lower()
	if clean.ends_with("-0"):
		clean = clean.substr(0, clean.length() - 2)
	return clean.replace("-", "_")
