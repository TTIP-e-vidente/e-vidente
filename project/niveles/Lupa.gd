extends Area2D
class_name Lupa

@onready var ayudin = $ayudin

func _on_area_entrado(area):
	var item_level = area.get_parent()
	item_level.show_info()
	

func _on_area_salido(area):
	var item_level = area.get_parent()
	item_level.show_texture()
