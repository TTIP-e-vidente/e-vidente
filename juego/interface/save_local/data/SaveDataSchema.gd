## Estructura y valores por defecto del archivo de guardado local.
##
## Define la forma canónica del save_data.json que se persiste en disco.
## Contiene los valores iniciales, la normalización de campos cargados
## desde disco, y la reparación de estructuras corruptas o incompletas.
##
## Estructura del archivo:
##   version            → Versión del esquema (actualmente 4)
##   profile            → Datos de identidad del jugador (ver SaveLocalProfileHelper)
##   progress           → Progreso de juego: campaña, racha y estado parcial
##   resume_state       → Dónde retomar al volver al juego (hub, libro, nivel)
##   history            → Historial de acciones recientes
##   save_meta          → Metadatos de la última escritura a disco
extends RefCounted

const SAVE_VERSION := 4
const DEFAULT_PROFILE_NAME := "Perfil local"
const HISTORY_LIMIT := 25
const ARCHIVERO_SCENE := "res://niveles/selector.tscn"


func datos_guardado_predeterminados() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"username": DEFAULT_PROFILE_NAME, "birth_date": "", "email": "",
			"avatar_path": "", "created_at": "", "updated_at": ""
		},
		"save_meta": {"last_saved_at": "", "last_saved_reason": "", "write_count": 0},
		"resume_state": estado_reanudacion_predeterminado().duplicate(true),
		"progress": {},
		"node_progress": {},
		"history": [],
		"played_activity_ids": [],
		"completed_activity_ids": [],
		"completed_activity_ids_by_request": {},
		"total_exp": 0
	}


func estado_reanudacion_predeterminado() -> Dictionary:
	return {
		"context": "hub",
		"track_key": "",
		"scene_path": ARCHIVERO_SCENE,
		"level_number": 1
	}


func normalizar_meta_guardado(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {
			"last_saved_at": "",
			"last_saved_reason": "",
			"write_count": 0,
			"linked_online_username": "",
		}
	return {
		"last_saved_at": str(raw.get("last_saved_at", "")),
		"last_saved_reason": str(raw.get("last_saved_reason", "")),
		"write_count": max(0, int(raw.get("write_count", 0))),
		"linked_online_username": str(raw.get("linked_online_username", "")).strip_edges(),
	}


func normalizar_historial(raw: Variant) -> Array:
	var result: Array = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func agregar_historial(save_data: Dictionary, message: String, metadata: Dictionary = {}) -> void:
	var stored: Variant = save_data.get("history", [])
	var entries: Array = stored if stored is Array else []
	entries.push_front({
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	})
	if entries.size() > HISTORY_LIMIT:
		entries = entries.slice(0, HISTORY_LIMIT)
	save_data["history"] = entries
