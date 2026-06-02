extends RefCounted


static func limitar_elementos_por_dificultad(dificultad: int) -> int:
	match clampi(dificultad, 1, 5):
		1:
			return 2
		2:
			return 3
		3:
			return 4
		4:
			return 5
		_:
			return 6


static func obtener_cantidad_de_distractores_por_dificultad(dificultad: int) -> int:
	match clampi(dificultad, 1, 5):
		1:
			return 1
		2:
			return 1
		3:
			return 2
		4:
			return 3
		_:
			return 3


static func deberia_mostrar_ayuda_visual(dificultad: int) -> bool:
	return clampi(dificultad, 1, 5) == 1