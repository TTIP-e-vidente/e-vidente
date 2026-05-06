extends RefCounted
class_name NodeContentValidator

# Wrapper temporal por compatibilidad con codigo viejo.
# Codigo nuevo: usar res://sistemas/contenido/ValidadorDeContenidoDeNodo.gd.
const ValidadorDeContenidoDeNodoScript := preload(
	"res://sistemas/contenido/ValidadorDeContenidoDeNodo.gd"
)


static func validar_datos_nodo(datos_nodo: Dictionary) -> String:
	return ValidadorDeContenidoDeNodoScript.validar_datos_nodo(datos_nodo)


static func limpiar_datos_nodo(datos_nodo: Dictionary) -> Dictionary:
	return ValidadorDeContenidoDeNodoScript.limpiar_datos_nodo(datos_nodo)


static func validar(datos_nodo: Dictionary) -> String:
	return ValidadorDeContenidoDeNodoScript.validar(datos_nodo)


static func limpiar(datos_nodo: Dictionary) -> Dictionary:
	return ValidadorDeContenidoDeNodoScript.limpiar(datos_nodo)
