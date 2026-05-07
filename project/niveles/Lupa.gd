extends Area2D
class_name Lupa

@onready var ayudin = $ayudin

func _on_area_entrado(area):
	var alimento := _obtener_alimento_desde_area(area)
	if alimento == null:
		return
	alimento.show_info()
	

func _on_area_salido(area):
	var alimento := _obtener_alimento_desde_area(area)
	if alimento == null:
		return
	alimento.show_texture()


func _obtener_alimento_desde_area(area: Area2D) -> Node:
	if area == null:
		return null
	var alimento := area.get_parent()
	if alimento == null:
		return null
	if not alimento.has_method("show_info") or not alimento.has_method("show_texture"):
		return null
	return alimento
