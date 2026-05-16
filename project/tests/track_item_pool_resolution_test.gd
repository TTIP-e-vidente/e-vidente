extends SceneTree

const GameTrackItemPoolCatalog := preload(
	"res://niveles/content/catalog/GameTrackItemPoolCatalog.gd"
)
const LevelItemScript := preload("res://resources/level_item.gd")

var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var celiac_safe_item: Resource = _make_item([])
	var celiac_blocked_item: Resource = _make_item([LevelItemScript.Condicion.CELIACO])
	var vegan_blocked_item: Resource = _make_item([LevelItemScript.Condicion.VEGETARIANO])
	var keto_default_item: Resource = _make_item([])
	var keto_allowed_item: Resource = _make_item([], PackedStringArray(["cetogenica"]))
	var forced_negative_item: Resource = _make_item(
		[],
		PackedStringArray(["celiaquia"]),
		PackedStringArray(["celiaquia"])
	)

	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"celiaquia",
			celiac_safe_item
		) == GameTrackItemPoolCatalog.POSITIVE_ITEMS_KEY,
		"Celiaquia deberia aceptar un item sin condicion bloqueante"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"celiaquia",
			celiac_blocked_item
		) == GameTrackItemPoolCatalog.NEGATIVE_ITEMS_KEY,
		"Celiaquia deberia bloquear items con condicion CELIACO"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"veganismo",
			vegan_blocked_item
		) == GameTrackItemPoolCatalog.NEGATIVE_ITEMS_KEY,
		"Veganismo deberia bloquear items con condicion VEGETARIANO"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"veganismo_celiaquia",
			celiac_blocked_item
		) == GameTrackItemPoolCatalog.NEGATIVE_ITEMS_KEY,
		"El track mixto deberia bloquear items incompatibles con celiaquia"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"cetogenica",
			keto_default_item
		) == GameTrackItemPoolCatalog.NEGATIVE_ITEMS_KEY,
		"Cetogenica deberia dejar items nuevos como negativos si no tienen metadata explicita"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"cetogenica",
			keto_allowed_item
		) == GameTrackItemPoolCatalog.POSITIVE_ITEMS_KEY,
		"Cetogenica deberia respetar allowed_track_keys en el propio item"
	)
	_assert(
		GameTrackItemPoolCatalog.classify_item_for_track(
			"celiaquia",
			forced_negative_item
		) == GameTrackItemPoolCatalog.NEGATIVE_ITEMS_KEY,
		"blocked_track_keys deberia tener prioridad sobre allowed_track_keys"
	)

	quit(1 if failed else 0)


func _make_item(
	raw_conditions: Array,
	allowed_tracks: PackedStringArray = PackedStringArray(),
	blocked_tracks: PackedStringArray = PackedStringArray()
) -> Resource:
	var item := LevelItemScript.new()
	item.condiciones.clear()
	for raw_condition in raw_conditions:
		item.condiciones.append(int(raw_condition))
	item.allowed_track_keys = allowed_tracks
	item.blocked_track_keys = blocked_tracks
	return item


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	printerr("TRACK ITEM POOL TEST FAILED: %s" % message)