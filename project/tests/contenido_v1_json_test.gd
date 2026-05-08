extends SceneTree

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")
const ContentValidatorScript := preload("res://sistemas/contenido/ContentValidator.gd")
const CargadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/CargadorDeContenidoDeNodo.gd"
)
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")

const ARCHIVOS_V1 := [
	"res://contenido/assets_catalog.json",
	"res://contenido/tests/fixtures/juegos/arrastre/alimentos_sin_tacc_nivel_1.json",
	"res://contenido/tests/fixtures/juegos/preguntas/celiaquia_basico.json",
	"res://contenido/tests/fixtures/juegos/recetas/desayuno_seguro_receta.json",
	"res://contenido/tests/fixtures/nodos/celiaquia/nodo_001_desayuno.json",
	"res://contenido/tests/fixtures/mapas/celiaquia_mapa_v1.json",
]

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	for ruta in ARCHIVOS_V1:
		_validar_archivo_v1(ruta)
	_validar_juegos_jugables()
	_validar_mapa_v1()
	quit(1 if fallo else 0)


func _validar_archivo_v1(ruta: String) -> void:
	var raw_result: Dictionary = ContentJsonLoaderScript.load_json(ruta)
	_assert(bool(raw_result.get("ok", false)), "No se pudo leer %s" % ruta)
	if not bool(raw_result.get("ok", false)):
		return
	var validation_result: Dictionary = ContentValidatorScript.validate(
		raw_result.get("data", {}),
		ruta
	)
	_assert(bool(validation_result.get("ok", false)), str(validation_result.get("error", "")))


func _validar_juegos_jugables() -> void:
	var rutas := [
		"res://contenido/tests/fixtures/juegos/arrastre/alimentos_sin_tacc_nivel_1.json",
		"res://contenido/tests/fixtures/juegos/preguntas/celiaquia_basico.json",
	]
	for ruta in rutas:
		var resultado: Dictionary = CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(ruta)
		_assert(bool(resultado.get("ok", false)), "No se pudo cargar juego V1: %s" % ruta)


func _validar_mapa_v1() -> void:
	var resultado: Dictionary = CargadorDeMapaScript.load_map(
		"res://contenido/tests/fixtures/mapas/celiaquia_mapa_v1.json"
	)
	_assert(bool(resultado.get("ok", false)), "No se pudo cargar el mapa V1")
	if not bool(resultado.get("ok", false)):
		return
	var nodos: Variant = resultado.get("data", {}).get("nodes", [])
	_assert(nodos is Array and (nodos as Array).size() == 1, "El mapa V1 debe exponer un nodo")
	if not nodos is Array or (nodos as Array).is_empty():
		return
	var node_data: MapNodeData = (nodos as Array)[0] as MapNodeData
	_assert(node_data != null, "El nodo V1 debe convertirse a MapNodeData")
	if node_data == null:
		return
	_assert(node_data.has_explicit_games(), "El nodo V1 debe conservar juegos explicitos")


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("CONTENIDO V1 TEST FAILED: %s" % mensaje)