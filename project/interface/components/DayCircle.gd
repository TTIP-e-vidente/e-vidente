extends TextureRect


enum Estado {
	COMPLETO,
	HOY,
	VACIO
}

func set_estado(e):
	match e:
		Estado.COMPLETO:
			modulate = Color(1,1,1)
		Estado.HOY:
			modulate = Color(1,1,0.6)
		Estado.VACIO:
			modulate = Color(0.5,0.5,0.5)
