extends RefCounted
class_name CargadorCompletar

const JSON_PATH := "res://contenido/mapa/completar_palabra.json"
const MODE := "completar_palabra"
const BLANK := "____"
const VALID_DIFFICULTIES := [1, 2, 3]
const ContentSchemaNormalizerScript := preload(
	"res://sistemas/contenido/ContentSchemaNormalizer.gd"
)

static var _cache: Dictionary = {}


static func elegir(dificultad: int) -> Dictionary:
	var todos: Dictionary = cargar_todo()
	if todos.is_empty():
		return {}

	var candidatos: Array[Dictionary] = _candidatos_por_dificultad(todos, dificultad)
	if candidatos.is_empty():
		push_warning("CargadorCompletar: sin desafíos para dificultad=%d en %s" % [dificultad, JSON_PATH])
		return {}

	candidatos.shuffle()
	var elegido: Dictionary = candidatos[0]

	var opciones_raw: Array = elegido.get("choices", elegido.get("options", []))
	var opciones: Array = opciones_raw.duplicate()
	opciones.shuffle()
	elegido["choices"] = opciones
	elegido["options"] = opciones
	return elegido


static func ids_por_dificultad(dificultad: int) -> Array[String]:
	var todos: Dictionary = cargar_todo()
	var candidatos: Array[Dictionary] = _candidatos_por_dificultad(todos, dificultad)
	var ids: Array[String] = []
	for entrada in candidatos:
		ids.append(str(entrada.get("id", "")))
	return ids


static func limpiar_cache() -> void:
	_cache = {}


static func cargar_todo() -> Dictionary:
	if not _cache.is_empty():
		return _cache

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("CargadorCompletar: no se pudo abrir '%s'." % JSON_PATH)
		return {}

	var parser := JSON.new()
	var texto: String = file.get_as_text()
	if parser.parse(texto) != OK:
		push_error("CargadorCompletar: JSON inválido en línea %d — %s" % [parser.get_error_line(), parser.get_error_message()])
		return {}

	var data: Variant = parser.get_data()
	if not data is Dictionary:
		push_error("CargadorCompletar: el JSON debe ser un objeto raíz {}.")
		return {}

	var datos: Dictionary = data as Dictionary
	for clave in datos.keys():
		var raw: Variant = datos[clave]
		if not raw is Dictionary:
			push_error("CargadorCompletar: '%s' debe ser un objeto." % str(clave))
			continue
		var entrada: Dictionary = ContentSchemaNormalizerScript.normalize_word_game(str(clave), raw as Dictionary)
		if _es_valido(str(clave), entrada):
			_cache[str(clave)] = entrada
	return _cache


static func _candidatos_por_dificultad(todos: Dictionary, dificultad: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for clave in todos.keys():
		var entrada: Dictionary = todos[clave]
		var diff: int = int(entrada.get("difficulty", 0))
		if diff == dificultad:
			resultado.append(entrada.duplicate(true))
	return resultado


static func _es_valido(id: String, entrada: Dictionary) -> bool:
	var modo: String = str(entrada.get("mode", ""))
	if modo != MODE:
		push_error("CargadorCompletar: '%s' tiene mode incorrecto." % id)
		return false

	var dificultad: int = int(entrada.get("difficulty", 0))
	if not VALID_DIFFICULTIES.has(dificultad):
		push_error("CargadorCompletar: '%s' tiene difficulty inválido (debe ser 1, 2 o 3)." % id)
		return false

	var respuestas: Array = entrada.get("correct_answers", entrada.get("answers", []))
	var opciones: Array = entrada.get("choices", entrada.get("options", []))
	var frase: String = str(entrada.get("prompt", entrada.get("sentence", "")))

	if respuestas.is_empty():
		push_error("CargadorCompletar: '%s' no tiene respuestas." % id)
		return false
	if opciones.is_empty():
		push_error("CargadorCompletar: '%s' no tiene opciones." % id)
		return false
	for respuesta in respuestas:
		if not opciones.has(respuesta):
			push_error("CargadorCompletar: '%s' tiene una respuesta que no está en las opciones." % id)
			return false

	var blanks: int = ContentSchemaNormalizerScript.count_blanks(frase)
	if blanks != respuestas.size():
		push_error("CargadorCompletar: '%s' tiene %d blanks pero %d respuestas." % [id, blanks, respuestas.size()])
		return false

	return true
