extends RefCounted
class_name PresentadorEnsenanzas

const ENSENANZA_ESC_SCENE := preload("res://ensenanzas/EnsenanzaEsc.tscn")
const CargadorEnsenanzasScript := preload("res://ensenanzas/CargadorEnsenanzas.gd")
const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

const TEACHING_KEY_FIELDS := [
	"teaching_key",
	"ensenanza",
	"ensenanza_key",
	"clave_ensenanza",
]


static func leer_teaching_key(datos: Dictionary) -> String:
	for campo in TEACHING_KEY_FIELDS:
		var clave: String = str(datos.get(campo, "")).strip_edges()
		if not clave.is_empty():
			return clave
	return ""


static func leer_teaching_key_de_fuentes(fuentes: Array) -> String:
	for fuente in fuentes:
		if fuente is Dictionary:
			var clave: String = leer_teaching_key(fuente as Dictionary)
			if not clave.is_empty():
				return clave
	return ""


static func _enriquecer_imagen_si_falta(
	ensenanza: Ensenanza,
	track_key: String,
	teaching_key: String,
	node_key: String,
	level_number: int
) -> void:
	if not ensenanza.imagen.is_empty() and ResourceLoader.exists(ensenanza.imagen):
		return
	var ruta: String = GameChapterAssetCatalogScript.resolver_ruta_ensenanza_para_contexto(
		track_key,
		teaching_key,
		node_key,
		"",
		level_number
	)
	if not ruta.is_empty():
		ensenanza.imagen = ruta


static func resolver_ensenanza_para_contexto(
	teaching_key: String,
	track_key: String = "celiaquia",
	node_key: String = "",
	level_number: int = 0
) -> Ensenanza:
	var clave: String = teaching_key.strip_edges()
	if clave.is_empty():
		return null
	var ensenanza: Ensenanza = CargadorEnsenanzasScript.resolver_por_teaching_key(clave)
	if ensenanza == null:
		return null
	_enriquecer_imagen_si_falta(ensenanza, track_key, clave, node_key, level_number)
	if (
		ensenanza.titulo.is_empty()
		and ensenanza.texto.is_empty()
		and ensenanza.imagen.is_empty()
	):
		return null
	return ensenanza


static func mostrar_en_host(
	host: Node,
	teaching_key: String,
	al_continuar: Callable,
	track_key: String = "celiaquia",
	node_key: String = "",
	level_number: int = 0
) -> bool:
	if host == null:
		return false
	var ensenanza: Ensenanza = resolver_ensenanza_para_contexto(
		teaching_key,
		track_key,
		node_key,
		level_number
	)
	if ensenanza == null:
		return false

	var capa := CanvasLayer.new()
	capa.layer = 90
	capa.name = "CapaEnsenanzaEsc"
	host.add_child(capa)

	var escena: Control = ENSENANZA_ESC_SCENE.instantiate()
	escena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(escena)
	escena.call_deferred("mostrar_ensenanza", ensenanza)

	if escena.has_signal("continuar_presionado"):
		escena.continuar_presionado.connect(
			func() -> void:
				if is_instance_valid(capa):
					capa.queue_free()
				if al_continuar.is_valid():
					al_continuar.call_deferred()
		)
	else:
		capa.queue_free()
		return false
	return true
