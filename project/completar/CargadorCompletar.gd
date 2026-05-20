extends RefCounted
class_name CargadorCompletar
## Carga y selecciona desafíos de la modalidad "Completar con opciones de palabras".
##
## Flujo de uso:
##   CargadorCompletar.pick(1)  →  Dictionary con el desafío listo para setup()
##   CargadorCompletar.pick(2)  →  {}  si no hay desafíos para esa dificultad
##
## El JSON se carga una sola vez y se guarda en caché (_cache).
## Para forzar recarga (tests), llamar limpiar_cache().

# === Constantes ===
const JSON_PATH := "res://contenido/mapa/completar_palabra.json"
const MODE := "completar_palabra"
const BLANK := "____"
const VALID_DIFFICULTIES := [1, 2, 3]

# Caché interna: evita re-leer el archivo en cada pick().
static var _cache: Dictionary = {}


# ===========================================================================
# API PÚBLICA
# ===========================================================================

## Devuelve un desafío aleatorio para la dificultad indicada.
## Retorna {} si no hay desafíos disponibles o el JSON no existe.
static func pick(difficulty: int) -> Dictionary:
	var all_challenges := load_all()
	if all_challenges.is_empty():
		return {}

	var candidates := _get_candidates_by_difficulty(all_challenges, difficulty)
	if candidates.is_empty():
		push_warning(
			"CargadorCompletar: sin desafíos para difficulty=%d en %s" % [difficulty, JSON_PATH]
		)
		return {}

	# Mezclar candidatos para mayor variedad entre sesiones
	candidates.shuffle()
	var chosen: Dictionary = candidates[0]

	# Mezclar las opciones del desafío elegido (ya es deep copy, seguro modificar)
	chosen["options"] = _shuffle_options(chosen.get("options", []))
	return chosen


## Devuelve todos los ids disponibles para una dificultad (útil para tests).
static func get_ids_for_difficulty(difficulty: int) -> Array[String]:
	var ids: Array[String] = []
	for entry in _get_candidates_by_difficulty(load_all(), difficulty):
		ids.append(str(entry.get("id", "")))
	return ids


## Limpia la caché interna. Usar en tests para forzar recarga del JSON.
static func limpiar_cache() -> void:
	_cache = {}


## Carga y devuelve todos los desafíos del JSON. Usa caché.
## Cada entrada incluye su id como campo "id".
static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = _load_json_file()
	return _cache


# ===========================================================================
# HELPERS PRIVADOS — cada uno hace una sola cosa
# ===========================================================================

## Lee el archivo JSON y devuelve un Dictionary con todas las entradas.
## Devuelve {} si el archivo no existe o el JSON es inválido.
static func _load_json_file() -> Dictionary:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("CargadorCompletar: no se pudo abrir '%s'." % JSON_PATH)
		return {}

	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error(
			"CargadorCompletar: JSON inválido en línea %d — %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return {}

	var data: Variant = parser.get_data()
	if not data is Dictionary:
		push_error("CargadorCompletar: el JSON debe ser un objeto raíz {}.")
		return {}

	# Inyectar el id de cada entrada como campo "id"
	var result: Dictionary = {}
	for key in (data as Dictionary).keys():
		var entry: Dictionary = ((data as Dictionary).get(key, {}) as Dictionary).duplicate(true)
		entry["id"] = str(key)
		# Validar antes de incluir en el resultado
		if _validate_challenge(str(key), entry):
			result[str(key)] = entry
	return result


## Filtra las entradas del JSON por dificultad.
## Devuelve un Array[Dictionary] con deep copies listas para modificar.
static func _get_candidates_by_difficulty(
	all_challenges: Dictionary,
	difficulty: int
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for key in all_challenges.keys():
		var entry: Dictionary = all_challenges[key]
		if int(entry.get("difficulty", 0)) == difficulty:
			candidates.append(entry.duplicate(true))
	return candidates


## Valida que un desafío cumple el contrato del JSON.
## Loga un error claro si algo falla. Devuelve true si es válido.
static func _validate_challenge(id: String, entry: Dictionary) -> bool:
	if str(entry.get("mode", "")) != MODE:
		push_error("CargadorCompletar: '%s' tiene mode incorrecto." % id)
		return false
	if not VALID_DIFFICULTIES.has(int(entry.get("difficulty", 0))):
		push_error("CargadorCompletar: '%s' tiene difficulty inválido (debe ser 1, 2 o 3)." % id)
		return false

	var answers: Array = entry.get("answers", [])
	var options: Array = entry.get("options", [])
	var sentence: String = str(entry.get("sentence", ""))

	if answers.is_empty():
		push_error("CargadorCompletar: '%s' no tiene answers." % id)
		return false
	if options.is_empty():
		push_error("CargadorCompletar: '%s' no tiene options." % id)
		return false
	if not _has_all_answers_in_options(answers, options):
		push_error(
			"CargadorCompletar: '%s' tiene answers que no están en options." % id
		)
		return false
	if _count_blanks(sentence) != answers.size():
		push_error(
			"CargadorCompletar: '%s' tiene %d blanks (____) pero %d answers."
			% [id, _count_blanks(sentence), answers.size()]
		)
		return false
	return true


## Cuenta cuántos ____ hay en la frase.
static func _count_blanks(sentence: String) -> int:
	var count := 0
	var search_start := 0
	while true:
		var idx := sentence.find(BLANK, search_start)
		if idx == -1:
			break
		count += 1
		search_start = idx + BLANK.length()
	return count


## Verifica que cada answer exista dentro de options (comparación exacta).
static func _has_all_answers_in_options(answers: Array, options: Array) -> bool:
	for answer in answers:
		if not options.has(answer):
			return false
	return true


## Devuelve una copia mezclada del array de opciones.
static func _shuffle_options(options: Array) -> Array:
	var shuffled := options.duplicate()
	shuffled.shuffle()
	return shuffled
