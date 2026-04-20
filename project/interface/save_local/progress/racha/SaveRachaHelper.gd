## Persistencia de la racha diaria (streak) en el save local.
##
## La racha registra cuántos días consecutivos el jugador realizó actividades.
## Se almacena dentro de progress.progress_system_states.streak en el JSON.
##
## Campos persistidos:
##   current_count      → Días consecutivos actuales
##   best_count         → Mejor racha histórica
##   last_activity_day  → Fecha (YYYY-MM-DD) de la última actividad
##   last_activity_type → Tipo de la última actividad (ej: "question_session_completed")
##   last_track_key     → Track donde se realizó la última actividad
##
## Flujo:
##   Runtime (Global._streak) → export_streak() → save_data.json
##   save_data.json → import_streak() → Runtime (Global._streak)
extends RefCounted

const STREAK_KEY := "streak"


## Extrae el diccionario de racha del snapshot de progreso que se lee de disco.
func import_streak(progress_snapshot: Dictionary) -> Dictionary:
	var systems: Variant = progress_snapshot.get("progress_system_states", {})
	var streak: Variant = systems.get(STREAK_KEY, {}) if systems is Dictionary else {}
	if streak is Dictionary:
		return (streak as Dictionary).duplicate(true)
	return {}


## Inyecta el estado de racha dentro del snapshot de progreso que se escribe a disco.
func export_streak(progress_snapshot: Dictionary, streak_state: Dictionary) -> void:
	if streak_state.is_empty():
		return
	progress_snapshot["progress_system_states"] = {
		STREAK_KEY: streak_state.duplicate(true)
	}
