extends Area2D

func _on_evento_entrada(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton:
		visible = event.is_pressed()
	
