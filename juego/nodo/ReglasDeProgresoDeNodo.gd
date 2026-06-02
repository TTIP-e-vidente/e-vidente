extends RefCounted
class_name ReglasDeProgresoDeNodo

const _Reglas := preload("res://sistemas/NodoProgressionRules.gd")

enum Dificultad {
	FACIL,   # niveles 1-2 → 6 EXP
	MEDIA,   # nivel 3    → 8 EXP
	DIFICIL, # niveles 4-5 → 12 EXP
}

const EXP_POR_DIFICULTAD := {
	Dificultad.FACIL:   6,
	Dificultad.MEDIA:   8,
	Dificultad.DIFICIL: 12,
}


static func dificultad_desde_valor(valor: int) -> Dificultad:
	match int(valor):
		1, 2: return Dificultad.FACIL
		3:    return Dificultad.MEDIA
		4, 5: return Dificultad.DIFICIL
		_:    return Dificultad.FACIL


static func obtener_exp_por_dificultad(dificultad: Dificultad) -> int:
	return EXP_POR_DIFICULTAD.get(dificultad, EXP_POR_DIFICULTAD[Dificultad.FACIL])


## Suma la EXP base de todos los mini juegos del nodo.
static func calcular_exp_base(juegos: Array, dificultad_fallback: int = 1) -> int:
	return _Reglas.calculate_base_exp(juegos, dificultad_fallback)


## EXP final = round(exp_base * precision_ratio). Nunca supera exp_base.
static func calcular_exp_final(exp_base: int, precision: float) -> int:
	return _Reglas.calculate_final_exp(exp_base, precision)


## Precisión como porcentaje entero 0–100.
static func calcular_precision(aciertos: int, intentos: int) -> int:
	return _Reglas.calculate_precision(aciertos, intentos)


## Precisión como ratio 0.0–1.0. Si no hay intentos, devuelve 1.0.
static func calcular_ratio_precision(aciertos: int, intentos: int) -> float:
	return _Reglas.calculate_precision_ratio(aciertos, intentos)


## Porcentaje de error como entero 0–100.
static func calcular_porcentaje_error(errores: int, intentos: int) -> int:
	return _Reglas.calculate_error_percent(errores, intentos)


## Formatea milisegundos a "M:SS".
static func formatear_tiempo(ms: int) -> String:
	return _Reglas.format_duration(ms)
