extends RefCounted

const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

var _manager


func _init(manager) -> void:
	_manager = manager


func connect_scene_nodes(level_scene: Node = null) -> bool:
	var scene_root: Node = level_scene if level_scene != null else _manager.get_parent()
	if scene_root == null:
		push_error("ManagerLevel no encontro la escena de nivel contenedora.")
		return false

	if not is_instance_valid(_manager.plato):
		_manager.plato = scene_root.get_node_or_null("Plato") as Plato
	if not is_instance_valid(_manager.meal_sprite):
		_manager.meal_sprite = scene_root.get_node_or_null("Globo texto/Meal") as Sprite2D
	if not is_instance_valid(_manager.condition_sprite):
		_manager.condition_sprite = scene_root.get_node_or_null(
			"Globo texto/Condition"
		) as Sprite2D
	if not is_instance_valid(_manager.teaching_sprite):
		_manager.teaching_sprite = scene_root.get_node_or_null("Ensenanza") as Sprite2D

	if (
		is_instance_valid(_manager.plato)
		and is_instance_valid(_manager.meal_sprite)
		and is_instance_valid(_manager.condition_sprite)
		and is_instance_valid(_manager.teaching_sprite)
	):
		return true

	push_error(
		"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
	)
	return false


func apply_run_textures(level_resource: LevelResource, run_data: Dictionary) -> void:
	level_resource.comida = GameChapterAssetCatalogScript.resolve_texture(
		run_data.get("meal_texture_path", "")
	)
	level_resource.condicion = GameChapterAssetCatalogScript.resolve_texture(
		run_data.get("condition_texture_path", "")
	)
	level_resource.ensenanza = GameChapterAssetCatalogScript.resolve_texture(
		run_data.get("teaching_texture_path", "")
	)
	_manager.meal_sprite.texture = level_resource.comida
	_manager.condition_sprite.texture = level_resource.condicion
	_manager.teaching_sprite.texture = level_resource.ensenanza
