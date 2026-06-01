extends Sprite2D

var tiempo := 0.0
var escala_base := Vector2.ONE

func _ready():
	escala_base = self.scale

func _process(delta):

	tiempo += delta

	var scale_offset: float = sin(tiempo) * 0.01

	self.scale = escala_base + Vector2(scale_offset, scale_offset)
