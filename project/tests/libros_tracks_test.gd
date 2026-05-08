extends SceneTree

const CASOS_LIBROS := [
	{
		"script": "res://interface/libro-vegan.gd",
		"track_key": "veganismo",
	},
	{
		"script": "res://interface/Libro-Vegan-GF.gd",
		"track_key": "veganismo_celiaquia",
	},
	{
		"script": "res://interface/Libro-Keto.gd",
		"track_key": "cetogenica",
	},
]

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	for caso in CASOS_LIBROS:
		await _validar_libro(caso)
	quit(1 if fallo else 0)


func _validar_libro(caso: Dictionary) -> void:
	var ruta_script: String = str(caso.get("script", "")).strip_edges()
	var script_libro: Script = load(ruta_script) as Script
	_assert(script_libro != null, "No se pudo cargar el script: %s" % ruta_script)
	if script_libro == null:
		return

	var libro: Node2D = _crear_libro_minimo(script_libro)
	get_root().add_child(libro)
	await process_frame

	var global: Node = get_root().get_node_or_null("/root/Global")
	_assert(global != null, "El autoload Global debe estar disponible.")
	if global == null:
		libro.queue_free()
		await process_frame
		return

	var track_key: String = str(caso.get("track_key", "")).strip_edges()
	var cantidad_esperada: int = int(global.call("obtener_pista_nivel_cantidad", track_key))
	var botones: Array[Button] = _obtener_botones_capitulo(libro)
	_assert(
		botones.size() == cantidad_esperada,
		"%s deberia tener %d capitulos, tiene %d."
		% [ruta_script, cantidad_esperada, botones.size()]
	)
	if not botones.is_empty():
		_assert(
			not botones[0].pressed.get_connections().is_empty(),
			"%s deberia conectar el primer capitulo." % ruta_script
		)

	libro.queue_free()
	await process_frame


func _crear_libro_minimo(script_libro: Script) -> Node2D:
	var libro := Node2D.new()
	libro.set_script(script_libro)

	var contenedor := VBoxContainer.new()
	contenedor.name = "VBoxContainer"
	libro.add_child(contenedor)
	for indice in range(1, 7):
		var boton := Button.new()
		boton.name = "Cap%d" % indice
		contenedor.add_child(boton)

	var titulo := Node2D.new()
	titulo.name = "TituloNivel"
	libro.add_child(titulo)
	var label := Label.new()
	label.name = "Label"
	titulo.add_child(label)

	return libro


func _obtener_botones_capitulo(libro: Node) -> Array[Button]:
	var botones: Array[Button] = []
	var contenedor: Node = libro.get_node_or_null("VBoxContainer")
	if contenedor == null:
		return botones
	for child in contenedor.get_children():
		var boton: Button = child as Button
		if boton == null:
			continue
		if not boton.name.begins_with("Cap"):
			continue
		botones.append(boton)
	return botones


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("LIBROS TRACKS TEST FAILED: %s" % mensaje)
