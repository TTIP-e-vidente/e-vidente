extends RefCounted


const GameChapterAssetCatalogScript := preload(
	"res://niveles/content/catalog/GameChapterAssetCatalog.gd"
)

var _gestor


func _init(manager) -> void:
	_gestor = manager


func conectar_escena_nodos(level_scene: Node = null) -> bool:
	var scene_root: Node = level_scene if level_scene != null else _gestor.get_parent()
	if scene_root == null:
		push_error("ManagerLevel no encontro la escena de nivel contenedora.")
		return false

	if not is_instance_valid(_gestor.plato):
		_gestor.plato = scene_root.get_node_or_null("Plato")
	if not is_instance_valid(_gestor.meal_sprite):
		_gestor.meal_sprite = scene_root.get_node_or_null("Globo texto/Meal") as Sprite2D
	if not is_instance_valid(_gestor.condition_sprite):
		_gestor.condition_sprite = scene_root.get_node_or_null(
			"Globo texto/Condition"
		) as Sprite2D
	if not is_instance_valid(_gestor.teaching_sprite):
		_gestor.teaching_sprite = scene_root.get_node_or_null("Ensenanza") as Sprite2D

	if (
		is_instance_valid(_gestor.plato)
		and is_instance_valid(_gestor.meal_sprite)
		and is_instance_valid(_gestor.condition_sprite)
		and is_instance_valid(_gestor.teaching_sprite)
	):
		return true

	push_error(
		"ManagerLevel no pudo resolver Plato, Meal, Condition o Ensenanza en la escena actual."
	)
	return false


func aplicar_texturas_partida(recurso_nivel, datos_partida: Dictionary) -> void:
	recurso_nivel.comida = GameChapterAssetCatalogScript.resolver_textura(
		datos_partida.get("meal_texture_path", "")
	)
	recurso_nivel.condicion = GameChapterAssetCatalogScript.resolver_textura(
		datos_partida.get("condition_texture_path", "")
	)
	recurso_nivel.ensenanza = GameChapterAssetCatalogScript.resolver_textura(
		datos_partida.get("teaching_texture_path", "")
	)
	_gestor.meal_sprite.texture = recurso_nivel.comida
	_gestor.condition_sprite.texture = recurso_nivel.condicion
	_gestor.teaching_sprite.texture = recurso_nivel.ensenanza
