extends Sprite2D

var tiempo := 0.0
var escala_base := Vector2.ONE

func _ready():
	escala_base = scale
	
func _process(delta):
	tiempo += delta

	var seno := sin(tiempo)


	var scale_offset := seno * 0.08
	scale = escala_base + Vector2.ONE * scale_offset

	modulate.a = 0.75 + seno * 0.5
	
