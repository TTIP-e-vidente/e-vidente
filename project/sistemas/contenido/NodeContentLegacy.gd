extends RefCounted
class_name NodeContentLegacy

# Wrapper temporal por compatibilidad con codigo viejo.
# Codigo nuevo: usar res://sistemas/contenido/AdaptadorContenidoViejo.gd.
const AdaptadorContenidoViejoScript := preload("res://sistemas/contenido/AdaptadorContenidoViejo.gd")


static func resolver_ruta_json(json_path: String) -> String:
	return AdaptadorContenidoViejoScript.resolver_ruta_json(json_path)


static func normalizar_datos_nodo(datos_crudos: Dictionary) -> Dictionary:
	return AdaptadorContenidoViejoScript.normalizar_datos_nodo(datos_crudos)


static func adaptar(datos_crudos: Dictionary) -> Dictionary:
	return AdaptadorContenidoViejoScript.adaptar(datos_crudos)
