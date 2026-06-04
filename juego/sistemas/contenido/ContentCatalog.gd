extends RefCounted
class_name ContentCatalog

# LEGACY_COMPAT: Usado por GameContentFactory, Global, ContentValidator.
# No agregar lógica nueva aquí; el contenido nuevo entra por NodeContentLoader.

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")

const CATALOG_PATHS := [
	"res://contenido/items.json",
	"res://contenido/catalogos/items_celiaquia.json",
	"res://contenido/assets_catalog.json",
]

static var _catalog_cache: Dictionary = {}
static var _catalog_loaded := false


static func cargar_catalogo() -> Dictionary:
	if _catalog_loaded:
		return _ok(_catalog_cache.duplicate(true))

	var raw_result: Dictionary = {}
	for catalog_path in CATALOG_PATHS:
		var resolved_path: String = ContentJsonLoaderScript.resolve_path(catalog_path)
		if resolved_path.is_empty() or not FileAccess.file_exists(resolved_path):
			continue
		raw_result = ContentJsonLoaderScript.cargar_json(catalog_path)
		if bool(raw_result.get("ok", false)):
			break
	if not bool(raw_result.get("ok", false)):
		return _error("No se pudo cargar ningun catalogo de items de contenido.")

	var catalog: Dictionary = raw_result.get("data", {})
	var items: Dictionary = _extract_items(catalog)
	if items.is_empty():
		return _error("items.json necesita ids de items como objeto.")

	_catalog_cache = {"items": items}
	_catalog_loaded = true
	return _ok(_catalog_cache.duplicate(true))


static func resolver_definicion_item(item_id: String) -> Dictionary:
	var catalog_result: Dictionary = cargar_catalogo()
	if not bool(catalog_result.get("ok", false)):
		return catalog_result

	var catalog: Dictionary = catalog_result.get("data", {})
	var items: Dictionary = catalog.get("items", {})
	var clean_item_id: String = item_id.strip_edges()
	if clean_item_id.is_empty():
		return _error("Asset no registrado en catalogo: \"\".")
	if not items.has(clean_item_id):
		return _error("Asset no registrado en catalogo: \"%s\"." % clean_item_id)

	return _ok((items.get(clean_item_id, {}) as Dictionary).duplicate(true))


static func resolve_item_runtime_data(item_id: String) -> Dictionary:
	var definition_result: Dictionary = resolver_definicion_item(item_id)
	if not bool(definition_result.get("ok", false)):
		return definition_result

	var definition: Dictionary = definition_result.get("data", {})
	var asset_path: String = ContentJsonLoaderScript.resolve_path(
		str(definition.get("resource", definition.get("asset", ""))).strip_edges()
	)
	if asset_path.is_empty() or not FileAccess.file_exists(asset_path):
		return _error(
			"Resource no encontrado en items.json: \"%s\"." % item_id
		)

	var item_resource: Resource = load(asset_path) as Resource
	if item_resource == null:
		return _error("No se pudo cargar el resource del item: %s" % asset_path)

	var image_path: String = ContentJsonLoaderScript.resolve_path(
		str(definition.get("imagen", definition.get("image", ""))).strip_edges()
	)
	var sprite: Texture2D = item_resource.get("sprite") as Texture2D
	var info: Texture2D = item_resource.get("info") as Texture2D
	var runtime_data := {
		"id": item_id.strip_edges(),
		"nombre": str(definition.get("nombre", item_id)).strip_edges(),
		"resource": asset_path,
		"categoria": str(
			definition.get(
				"categoria",
				item_resource.get("categoria") if item_resource != null else ""
			)
		).strip_edges(),
		"tags": definition.get("tags", []),
		"image": image_path if not image_path.is_empty() else (
			sprite.resource_path if sprite != null else ""
		),
		"info_image": info.resource_path if info != null else "",
	}
	return _ok(runtime_data)


static func _extract_items(catalog: Dictionary) -> Dictionary:
	if catalog.has("items") and catalog.get("items") is Dictionary:
		return (catalog.get("items", {}) as Dictionary).duplicate(true)
	return catalog.duplicate(true)


static func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}