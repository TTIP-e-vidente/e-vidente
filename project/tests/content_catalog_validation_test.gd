extends SceneTree

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")
const GameLevelContentCatalogScript := preload(
	"res://niveles/content/GameLevelContentCatalog.gd"
)
const KETO_TRACK_KEY := "cetogenica"

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var catalog = GameLevelContentCatalogScript.new()
	_validate_catalog(catalog)

	for track_definition in GameTrackCatalog.get_track_definitions():
		_validate_track(track_definition, catalog)

	quit(1 if failed else 0)


func _validate_catalog(catalog) -> void:
	var issues: Array[String] = catalog.get_validation_issues()
	_assert(catalog.is_valid(), "El catalogo de contenido deberia ser valido")
	_assert(issues.is_empty(), _format_issues(issues))


func _validate_track(track_definition: Dictionary, catalog) -> void:
	var track_key := str(track_definition.get("key", "")).strip_edges()
	var book_scene_path := str(track_definition.get("book_scene_path", ""))
	var level_scene_path := str(track_definition.get("level_scene_path", ""))
	var expected_level_count := max(
		1,
		int(track_definition.get("level_count", GameTrackCatalog.DEFAULT_LEVEL_COUNT))
	)

	_validate_track_metadata(
		track_key,
		book_scene_path,
		level_scene_path,
		expected_level_count,
		catalog
	)
	_validate_track_level_resource(
		track_key,
		level_scene_path,
		expected_level_count,
		catalog
	)
	_validate_track_chapters(track_key, expected_level_count, catalog)


func _validate_track_metadata(
	track_key: String,
	book_scene_path: String,
	level_scene_path: String,
	expected_level_count: int,
	catalog
) -> void:
	_assert(
		catalog.get_track_level_count(track_key, 0) == expected_level_count,
		(
			"El track %s deberia exponer la misma cantidad de capitulos que "
			+ "GameTrackCatalog"
		)
		% track_key
	)
	_assert(
		ResourceLoader.exists(book_scene_path),
		"El track %s deberia apuntar a una escena de libro existente" % track_key
	)
	_assert(
		ResourceLoader.exists(level_scene_path),
		"El track %s deberia apuntar a una escena de nivel existente" % track_key
	)


func _validate_track_chapters(
	track_key: String,
	expected_level_count: int,
	catalog
) -> void:
	for level_number in range(1, expected_level_count + 1):
		var chapter_definition: Dictionary = catalog.get_chapter_definition(
			track_key,
			level_number
		)
		var run_count: int = int(catalog.get_chapter_run_count(track_key, level_number))
		_assert(
			not chapter_definition.is_empty(),
			"El track %s deberia exponer el capitulo %d" % [track_key, level_number]
		)
		_assert(
			run_count >= 1,
			"El capitulo %d del track %s deberia tener al menos una corrida"
			% [level_number, track_key]
		)
		if track_key == KETO_TRACK_KEY:
			_validate_keto_chapter(chapter_definition)


func _validate_keto_chapter(chapter_definition: Dictionary) -> void:
	var runs: Array = chapter_definition.get("runs", [])
	for run_definition in runs:
		_assert(
			str((run_definition as Dictionary).get("teaching_key", "")).begins_with(
				"keto_"
			),
			"Cetogenica deberia usar teaching keys propias en el catalogo"
		)


func _validate_track_level_resource(
	track_key: String,
	level_scene_path: String,
	expected_level_count: int,
	catalog
) -> void:
	var level_scene: PackedScene = load(level_scene_path) as PackedScene
	_assert(
		level_scene != null,
		"El track %s deberia poder cargar su escena jugable" % track_key
	)
	if level_scene == null:
		return

	var level_instance: Node = level_scene.instantiate()
	_assert(
		level_instance != null,
		"El track %s deberia poder instanciar su escena jugable" % track_key
	)
	if level_instance == null:
		return

	var manager_level = level_instance.get_node_or_null("ManagerLevel")
	_assert(
		manager_level != null,
		"La escena %s deberia exponer un ManagerLevel" % level_scene_path
	)
	if manager_level == null:
		level_instance.free()
		return

	_assert(
		manager_level.level_resource != null,
		"La escena %s deberia exponer un LevelResource en ManagerLevel"
		% level_scene_path
	)
	_assert(
		level_instance.has_method("_get_resume_track_key"),
		"La escena %s deberia exponer el track jugable del nivel"
		% level_scene_path
	)
	if level_instance.has_method("_get_resume_track_key"):
		var resume_track_key := str(level_instance.call("_get_resume_track_key"))
		_assert(
			resume_track_key == track_key,
			"La escena %s deberia estar alineada con el track %s"
			% [level_scene_path, track_key]
		)
	if manager_level.level_resource != null:
		_validate_level_item_pools(
			track_key,
			expected_level_count,
			catalog,
			manager_level.level_resource
		)

	level_instance.free()


func _validate_level_item_pools(
	track_key: String,
	expected_level_count: int,
	catalog,
	level_resource
) -> void:
	var positive_pool: Array = level_resource.get_positive_items(track_key)
	var negative_pool: Array = level_resource.get_negative_items(track_key)
	for level_number in range(1, expected_level_count + 1):
		var run_count: int = int(catalog.get_chapter_run_count(track_key, level_number))
		for run_index in range(1, run_count + 1):
			var run_definition: Dictionary = catalog.get_chapter_run_definition(
				track_key,
				level_number,
				run_index
			)
			_validate_run_item_availability(
				track_key,
				level_number,
				run_index,
				run_definition,
				positive_pool,
				negative_pool,
				catalog
			)


func _validate_run_item_availability(
	track_key: String,
	level_number: int,
	run_index: int,
	run_definition: Dictionary,
	positive_pool: Array,
	negative_pool: Array,
	catalog
) -> void:
	var category := str(run_definition.get("category", ""))
	var required_positive_count: int = int(run_definition.get("positive_count", 0))
	var required_negative_count: int = int(run_definition.get("negative_count", 0))
	var available_positive_items: Array = catalog.filter_items_by_category(
		positive_pool,
		category
	)
	var available_negative_items: Array = catalog.filter_items_by_category(
		negative_pool,
		category
	)
	_assert(
		available_positive_items.size() >= required_positive_count,
		_build_pool_availability_message(
			track_key,
			level_number,
			run_index,
			required_positive_count,
			category,
			available_positive_items.size(),
			"positivos"
		)
	)
	_assert(
		available_negative_items.size() >= required_negative_count,
		_build_pool_availability_message(
			track_key,
			level_number,
			run_index,
			required_negative_count,
			category,
			available_negative_items.size(),
			"negativos"
		)
	)


func _build_pool_availability_message(
	track_key: String,
	level_number: int,
	run_index: int,
	required_count: int,
	category: String,
	available_count: int,
	pool_kind: String
) -> String:
	return (
		"El track %s capitulo %d corrida %d necesita %d items %s "
		+ "de categoria %s y la escena solo ofrece %d"
	) % [
		track_key,
		level_number,
		run_index,
		required_count,
		pool_kind,
		category,
		available_count
	]


func _format_issues(issues: Array[String]) -> String:
	if issues.is_empty():
		return "Sin issues"
	return "El catalogo de contenido tiene problemas:\n- %s" % "\n- ".join(issues)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("CONTENT CATALOG VALIDATION TEST FAILED: %s" % message)
