extends Area2D

func _ready(): 
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)
	
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton:
		visible = event.is_pressed()
	
