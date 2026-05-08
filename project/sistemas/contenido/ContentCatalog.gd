extends RefCounted
class_name ContentCatalog

const ContentJsonLoaderScript := preload("res://sistemas/contenido/ContentJsonLoader.gd")

const CATALOG_PATHS := [
	"res://contenido/items.json",
	"res://contenido/catalogos/items_celiaquia.json",
	"res://contenido/assets_catalog.json",
]

static var _catalog_cache: Dictionary = {}
static var _catalog_loaded := false


static func load_catalog() -> Dictionary:
	if _catalog_loaded:
		return _ok(_catalog_cache.duplicate(true))

	var raw_result: Dictionary = {}
	for catalog_path in CATALOG_PATHS:
		var resolved_path: String = ContentJsonLoaderScript.resolve_path(catalog_path)
		if resolved_path.is_empty() or not FileAccess.file_exists(resolved_path):
			continue
		raw_result = ContentJsonLoaderScript.load_json(catalog_path)
		if bool(raw_result.get("ok", false)):
			break
	if not bool(raw_result.get("ok", false)):
		return _error("No se pudo cargar ningun catalogo de items de contenido.")

	var catalog: Dictionary = raw_result.get("data", {})
	var items: Variant = catalog.get("items", {})
	if not items is Dictionary:
		return _error("assets_catalog.json necesita items como objeto.")

	_catalog_cache = catalog.duplicate(true)
	_catalog_loaded = true
	return _ok(_catalog_cache.duplicate(true))


static func resolve_item_definition(item_id: String) -> Dictionary:
	var catalog_result: Dictionary = load_catalog()
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
	var definition_result: Dictionary = resolve_item_definition(item_id)
	if not bool(definition_result.get("ok", false)):
		return definition_result

	var definition: Dictionary = definition_result.get("data", {})
	var asset_path: String = ContentJsonLoaderScript.resolve_path(
		str(definition.get("asset", "")).strip_edges()
	)
	if asset_path.is_empty() or not FileAccess.file_exists(asset_path):
		return _error("Asset no encontrado en assets_catalog.json: \"%s\"." % item_id)

	var item_resource: Resource = load(asset_path) as Resource
	if item_resource == null:
		return _error("No se pudo cargar el asset del catalogo: %s" % asset_path)

	var sprite: Texture2D = item_resource.get("sprite") as Texture2D
	var info: Texture2D = item_resource.get("info") as Texture2D
	var runtime_data := {
		"id": item_id.strip_edges(),
		"nombre": str(definition.get("nombre", item_id)).strip_edges(),
		"asset": asset_path,
		"categoria": str(definition.get("categoria", "")).strip_edges(),
		"tags": definition.get("tags", []),
		"image": sprite.resource_path if sprite != null else "",
		"info_image": info.resource_path if info != null else "",
	}
	return _ok(runtime_data)


static func _ok(data: Dictionary) -> Dictionary:
	return {"ok": true, "data": data, "error": ""}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "data": {}, "error": message}