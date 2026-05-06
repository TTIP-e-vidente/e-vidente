extends RefCounted
class_name NodeContentLoader

# Wrapper temporal por compatibilidad con codigo viejo.
# Codigo nuevo: usar res://sistemas/contenido/CargadorDeContenidoDeNodo.gd.
const CargadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/CargadorDeContenidoDeNodo.gd"
)

const MODE_QUIZ_CHOICE := CargadorDeContenidoDeNodoScript.MODE_QUIZ_CHOICE
const MODE_DRAG_DROP := CargadorDeContenidoDeNodoScript.MODE_DRAG_DROP
const MODE_VINCULACION_CONCEPTOS := CargadorDeContenidoDeNodoScript.MODE_VINCULACION_CONCEPTOS


static func cargar_contenido_nodo(ruta_json: String) -> Dictionary:
	return CargadorDeContenidoDeNodoScript.cargar_contenido_nodo(ruta_json)


static func cargar_desde_ruta(ruta_json: String) -> Dictionary:
	return CargadorDeContenidoDeNodoScript.cargar_desde_ruta(ruta_json)


static func cargar_desde_nodo(datos_nodo: Variant) -> Dictionary:
	return CargadorDeContenidoDeNodoScript.cargar_desde_nodo(datos_nodo)


static func convertir_arrastre_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	return CargadorDeContenidoDeNodoScript.convertir_arrastre_a_runtime(datos_nodo)


static func convertir_vinculacion_a_runtime(datos_nodo: Dictionary) -> Dictionary:
	return CargadorDeContenidoDeNodoScript.convertir_vinculacion_a_runtime(datos_nodo)
