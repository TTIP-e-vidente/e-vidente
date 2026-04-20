## Persistencia del progreso de campaña (niveles completados) en el save local.
##
## La campaña registra qué niveles de cada track fueron completados.
## Se almacena como arrays de booleanos por track_key en el JSON de progreso.
##
## Estructura persistida (dentro de progress):
##   current_level         → Último nivel activo del jugador
##   [track_key]           → Array[bool] — un booleano por nivel (índice 0 = nivel 1)
##                           true = completado, false = pendiente
##
## Ejemplo en disco:
##   "progress": {
##       "current_level": 3,
##       "vegan": [true, true, false, false, false],
##       "keto":  [true, false, false]
##   }
##
## Flujo:
##   Runtime (Global._completed) → export_campana() → save_data.json
##   save_data.json → import_campana() → Runtime (Global._completed)
extends RefCounted

const GameTrackCatalog := preload("res://niveles/GameTrackCatalog.gd")


## Exporta los flags de niveles completados al snapshot de progreso para disco.
func export_campana(
	completed: Dictionary,
	current_level: int,
	get_track_level_count: Callable
) -> Dictionary:
	var snapshot: Dictionary = {"current_level": current_level}
	for track_key in GameTrackCatalog.TRACK_ORDER:
		_ensure_track_flags(completed, track_key, get_track_level_count)
		snapshot[track_key] = completed[track_key].duplicate()
	return snapshot


## Importa los flags de niveles completados desde el snapshot leído de disco.
func import_campana(
	snapshot: Dictionary,
	completed: Dictionary,
	get_track_level_count: Callable
) -> int:
	var current_level: int = clampi(int(snapshot.get("current_level", 1)), 1, 999)
	for track_key in GameTrackCatalog.TRACK_ORDER:
		var raw_flags: Variant = snapshot.get(track_key, [])
		if not raw_flags is Array:
			continue
		_ensure_track_flags(completed, track_key, get_track_level_count)
		var flags: Array = completed[track_key]
		for i in range(mini(raw_flags.size(), flags.size())):
			flags[i] = bool(raw_flags[i])
	return current_level


## Verifica si un nivel específico está marcado como completado en datos de disco.
func is_level_completed_in_save(
	progress: Dictionary,
	track_key: String,
	level_number: int
) -> bool:
	var flags: Variant = progress.get(track_key, [])
	if not flags is Array:
		return false
	var idx: int = level_number - 1
	if idx < 0 or idx >= flags.size():
		return false
	return bool(flags[idx])


func _ensure_track_flags(
	completed: Dictionary,
	track_key: String,
	get_track_level_count: Callable
) -> void:
	if completed.has(track_key):
		return
	var count: int = get_track_level_count.call(track_key)
	var flags: Array = []
	flags.resize(count)
	flags.fill(false)
	completed[track_key] = flags
