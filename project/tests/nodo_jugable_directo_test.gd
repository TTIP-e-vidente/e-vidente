extends SceneTree

const ArmadorDePartidaScript := preload("res://mapas/logica/ArmadorDePartida.gd")
const CargadorDeMapaScript := preload("res://mapas/logica/CargadorDeMapa.gd")
const CargadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/CargadorDeContenidoDeNodo.gd"
)

const MAP_PATH := "res://contenido/mapas/celiaquia.json"

var fallo := false


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	var resultado_mapa: Dictionary = CargadorDeMapaScript.load_map(MAP_PATH)
	_assert(
		bool(resultado_mapa.get("ok", false)),
		"El mapa con nodo jugable debe cargar. %s" % str(resultado_mapa.get("error", ""))
	)
	if fallo:
		quit(1)
		return

	var nodos: Array = resultado_mapa.get("data", {}).get("nodes", [])
	_assert(nodos.size() == 1, "El fixture debe exponer un solo nodo.")
	if fallo:
		quit(1)
		return

	var nodo: MapNodeData = nodos[0] as MapNodeData
	_assert(nodo != null, "El nodo jugable debe convertirse a MapNodeData.")
	_assert(not nodo.has_explicit_games(), "El nodo jugable directo no debe crear game_entries.")
	_assert(nodo.mode == MapNodeData.MODE_DRAG_DROP, "El nodo jugable debe mapear a drag_drop.")
	_assert(
		nodo.json_path.ends_with("contenido/nodos/celiaquia/arrastre/receta_1_desayuno.json"),
		"El nodo jugable debe conservar la ruta del archivo apuntado."
	)

	var resultado_contenido: Dictionary = CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(
		nodo.json_path
	)
	_assert(
		bool(resultado_contenido.get("ok", false)),
		"El nodo jugable directo debe convertirse a contenido runtime."
	)
	if not bool(resultado_contenido.get("ok", false)):
		quit(1)
		return
	var datos_runtime: Dictionary = resultado_contenido.get("data", {})
	var contenido_runtime: Dictionary = datos_runtime.get("content", {})
	_assert(
		str(contenido_runtime.get("instruction", ""))
		== "Arrastrá al plato solo opciones aptas sin TACC para el desayuno.",
		"consigna debe transformarse a instruction."
	)
	var targets: Array = contenido_runtime.get("targets", [])
	_assert(not targets.is_empty(), "El runtime debe crear un target automatico.")
	if targets.is_empty():
		quit(1)
		return
	_assert(
		str((targets[0] as Dictionary).get("label", "")) == "Desayuno apto",
		"plato debe transformarse en el label del target."
	)
	_assert(
		str(contenido_runtime.get("teaching_key", "")) == "celiaquia_1",
		"ensenanza debe transformarse a teaching_key."
	)

	var plan: Dictionary = ArmadorDePartidaScript.construir_plan_de_partida(nodo)
	var juegos: Array = plan.get("juegos", [])
	_assert(juegos.size() == 1, "El primer nodo jugable debe generar un solo juego.")
	_assert(
		str(juegos[0].get("json_path", "")) == nodo.json_path,
		"El plan debe jugar el mismo archivo del nodo jugable."
	)

	quit(1 if fallo else 0)


func _assert(condicion: bool, mensaje: String) -> void:
	if condicion:
		return
	fallo = true
	printerr("NODO JUGABLE TEST FAILED: %s" % mensaje)