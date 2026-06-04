extends RefCounted
class_name NodoProgressionRules

enum Difficulty {
	EASY,    
	MEDIUM,  
	HARD,    
}

const EXP_BY_DIFFICULTY: Dictionary = {
	Difficulty.EASY:   6,
	Difficulty.MEDIUM: 8,
	Difficulty.HARD:   12,
}

static func difficulty_from_value(value: Variant) -> Difficulty:
	match int(value):
		1, 2:
			return Difficulty.EASY
		3:
			return Difficulty.MEDIUM
		4, 5:
			return Difficulty.HARD
		_:
			return Difficulty.EASY


## Devuelve los EXP base de un nivel de dificultad.
static func obtener_exp_por_dificultad(difficulty: Difficulty) -> int:
	return EXP_BY_DIFFICULTY.get(difficulty, EXP_BY_DIFFICULTY[Difficulty.EASY])


## Devuelve los EXP base de un valor entero de dificultad (1–5).
static func obtener_exp_por_dificultad_value(value: Variant) -> int:
	return obtener_exp_por_dificultad(difficulty_from_value(value))


static func calculate_base_exp(games: Array, dificultad_fallback: int = 1) -> int:
	if games.is_empty():
		return obtener_exp_por_dificultad_value(dificultad_fallback)
	var total: int = 0
	for raw in games:
		var game: Dictionary = raw as Dictionary
		if game == null:
			continue
		var d: int = max(1, int(game.get("dificultad", dificultad_fallback)))
		total += obtener_exp_por_dificultad_value(d)
	return total if total > 0 else obtener_exp_por_dificultad_value(dificultad_fallback)


# ─── Precisión y error ───────────────────────────────────────────────────────

## Precisión como ratio 0.0–1.0.
## Si no hay intentos, devuelve 1.0 (perfecto).
static func calcular_precision_ratio(correct: int, attempts: int) -> float:
	if attempts <= 0:
		return 1.0
	return clampf(float(correct) / float(attempts), 0.0, 1.0)


## Precisión como porcentaje entero 0–100.
static func calcular_precision(correct: int, attempts: int) -> int:
	return int(round(calcular_precision_ratio(correct, attempts) * 100.0))


## Porcentaje de error como entero 0–100.
static func calculate_error_percent(errors: int, attempts: int) -> int:
	if attempts <= 0:
		return 0
	return int(round(clampf(float(errors) / float(attempts), 0.0, 1.0) * 100.0))


# ─── EXP final ───────────────────────────────────────────────────────────────

## EXP final = round(exp_base * precision_ratio).
## Nunca puede ser menor que 0 ni mayor que exp_base.
static func calcular_exp_final(base_exp: int, precision_ratio: float) -> int:
	return clampi(int(round(float(base_exp) * precision_ratio)), 0, base_exp)


# ─── Tiempo ──────────────────────────────────────────────────────────────────

## Formatea duración en milisegundos a "M:SS".
static func formatear_duracion(ms: int) -> String:
	if ms <= 0:
		return "0:00"
	var total_seconds: int = int(ms / 1000.0)
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	return "%d:%02d" % [minutes, seconds]
