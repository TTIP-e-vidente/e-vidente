extends RefCounted
class_name CargadorEnsenanzas

static func cargar() -> Array[Ensenanza]:
	var archivo = FileAccess.open(
		"res://contenido/mapa/ensenanzas.json",
		FileAccess.READ
	)

	var datos = JSON.parse_string(
		archivo.get_as_text()
	)

	var resultado: Array[Ensenanza] = []

	for item in datos["ensenanzas"]:
		var ensenanza = Ensenanza.new()

		ensenanza.id = item["id"]
		ensenanza.titulo = item["titulo"]
		ensenanza.texto = item["texto"]
		ensenanza.imagen = item["imagen"]

		resultado.append(ensenanza)

	return resultado
