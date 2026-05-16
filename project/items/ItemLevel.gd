extends Node2D
class_name Item_level

signal intento_incorrecto  # emitido cuando un item negativo se suelta sobre el plato

@onready var sprite_2d = $Sprite2D
@onready var area_2d = $Area2D
var condiciones: Array[int] = []
var body_ref 
var plato 
var offset = get_global_mouse_position() - global_position
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
var base_scale := Vector2.ONE
static var is_dragging: Object = null

func setup(level_item, superficie, is_positive: bool, instance_id: String = ""):
	base_scale = scale
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
	scale = base_scale
	if is_instance_valid(area_2d):
		area_2d.input_pickable = interaction_enabled


func is_interaction_enabled() -> bool:
	return interaction_enabled


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
			offset = get_global_mouse_position() - global_position
			is_dragging = self
		if Input.is_action_pressed("click") && is_dragging == self:
			global_position = get_global_mouse_position() - offset
		elif Input.is_action_just_released("click") && is_dragging == self:
			is_dragging = null
			if is_inside_droppable and is_instance_valid(body_ref):
				print(
					"[ARRASTRE] item=",
					save_instance_id if not save_instance_id.is_empty() else item_resource_path,
					" target=",
					body_ref.name,
					" correcto=",
					body_ref == plato and esPositivo
				)
				if body_ref == plato:
					print(
						"[ManagerLevelItem] placed id=%s detail=%s"
						% [
							item_id if not item_id.is_empty() else save_instance_id,
							info.resource_path if info != null else "",
						]
					)
					plato.reaccionar_comida(self)
					if esPositivo:
						_animar_feedback_correcto()
					else:
						intento_incorrecto.emit()
						_animar_feedback_incorrecto()
				else:
					_volver_a_inicio()
			else:
				print(
					"[ARRASTRE] item=",
					save_instance_id if not save_instance_id.is_empty() else item_resource_path,
					" target=",
					"",
					" correcto=",
					false
				)
				_volver_a_inicio()

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
		scale = base_scale * 1.2

func _on_area_2d_mouse_exited():
	if not interaction_enabled:
		return
	if !is_dragging:
		draggable = false
		scale = base_scale


func _volver_a_inicio() -> void:
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", base_scale, 0.18)


func _animar_feedback_correcto() -> void:
	modulate = Color(1, 1, 1, 1)
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", base_scale * 1.12, 0.08)
	tween.tween_property(self, "scale", base_scale, 0.14)


func _animar_feedback_incorrecto() -> void:
	var posicion_actual := global_position
	var tween := get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.parallel().tween_property(self, "scale", base_scale, 0.18)


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
