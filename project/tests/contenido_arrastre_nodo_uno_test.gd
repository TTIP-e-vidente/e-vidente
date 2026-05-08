extends SceneTree

const CargadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/CargadorDeContenidoDeNodo.gd"
)
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

const TRACK_CELIAQUIA := "celiaquia"
const CASOS := [
	{
		"ruta": "res://contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json",
		"teaching_key": "celiaquia_1",
		"items_correctos": 4,
		"items_incorrectos": 3,
		"elementos_maximos": 3,
		"distractores_maximos": 1,
		"mostrar_ayuda_visual": true,
	},
	{
		"ruta": "res://contenido/nodos/celiaquia/arrastre/receta_3_almuerzo.json",
		"teaching_key": "celiaquia_3",
	},
	{
		"ruta": "res://contenido/nodos/celiaquia/arrastre/nuevo_nodo.json",
		"teaching_key": "celiaquia_3",
		"elementos_maximos": 3,
		"distractores_maximos": 1,
		"mostrar_ayuda_visual": true,
	},
]

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	for caso in CASOS:
		_validar_caso(caso)
	quit(1 if fallo else 0)


func _validar_caso(caso: Dictionary) -> void:
	var ruta: String = str(caso.get("ruta", "")).strip_edges()
	var resultado_nodo: Dictionary = CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(ruta)
	_assert(bool(resultado_nodo.get("ok", false)), "No se pudo cargar: %s" % ruta)
	if not bool(resultado_nodo.get("ok", false)):
		return

	var resultado_runtime: Dictionary = (
		CargadorDeContenidoDeNodoScript.convertir_arrastre_a_runtime(
		resultado_nodo.get("data", {})
		)
	)
	_assert(bool(resultado_runtime.get("ok", false)), "No se pudo convertir: %s" % ruta)
	if not bool(resultado_runtime.get("ok", false)):
		return

	var datos: Dictionary = resultado_runtime.get("data", {})
	var teaching_key: String = str(datos.get("teaching_key", "")).strip_edges()
	_assert(teaching_key == caso.get("teaching_key", ""), "Teaching key incorrecta en %s." % ruta)
	_assert(
		GameChapterAssetCatalogScript.resolver_textura_ensenanza_para_contexto(
			TRACK_CELIAQUIA,
			teaching_key,
			str(datos.get("node_key", "")),
			"",
			0
		) != null,
		"No existe asset real de ensenanza para %s." % ruta
	)
	_assert(_contar_items(datos, true) >= 1, "Falta al menos un item correcto en %s." % ruta)
	_assert(_contar_items(datos, false) >= 1, "Falta al menos un distractor en %s." % ruta)
	if caso.has("items_correctos"):
		_assert(
			_contar_items(datos, true) == int(caso.get("items_correctos", 0)),
			"Cantidad de items correctos incorrecta en %s." % ruta
		)
	if caso.has("items_incorrectos"):
		_assert(
			_contar_items(datos, false) == int(caso.get("items_incorrectos", 0)),
			"Cantidad de items incorrectos incorrecta en %s." % ruta
		)
	if caso.has("elementos_maximos"):
		_assert(
			int(datos.get("elementos_maximos", 0)) == int(caso.get("elementos_maximos", 0)),
			"elementos_maximos incorrecto en %s." % ruta
		)
	if caso.has("distractores_maximos"):
		_assert(
			int(datos.get("distractores_maximos", -1)) == int(caso.get("distractores_maximos", -1)),
			"distractores_maximos incorrecto en %s." % ruta
		)
	if caso.has("mostrar_ayuda_visual"):
		_assert(
			bool(datos.get("mostrar_ayuda_visual", false))
			== bool(caso.get("mostrar_ayuda_visual", false)),
			"mostrar_ayuda_visual incorrecto en %s." % ruta
		)


func _contar_items(datos: Dictionary, correctos: bool) -> int:
	var cantidad := 0
	for item in datos.get("items", []):
		if not item is Dictionary:
			continue
		var item_diccionario: Dictionary = item
		var es_correcto: bool = not str(item_diccionario.get("correct_target", "")).is_empty()
		if es_correcto == correctos:
			cantidad += 1
	return cantidad


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("ARRASTRE NODO 1 TEST FAILED: %s" % mensaje)
