extends RefCounted

var _profile_helper
var _config: Dictionary = {}
var _default_save_data: Callable
var _normalize_profile_data: Callable
var _normalize_save_meta: Callable
var _normalize_history: Callable


func _init(profile_helper, config: Dictionary, default_save_data: Callable, normalize_profile_data: Callable, normalize_save_meta: Callable, normalize_history: Callable):
	_profile_helper = profile_helper
	_config = config.duplicate(true)
	_default_save_data = default_save_data
	_normalize_profile_data = normalize_profile_data
	_normalize_save_meta = normalize_save_meta
	_normalize_history = normalize_history


func migrate_legacy_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized: Dictionary = _default_save_data.call()
	var selected_user: Dictionary = _resolve_selected_legacy_user(raw_data)
	if selected_user.is_empty():
		return normalized

	normalized["profile"] = _normalize_profile_data.call({
		"username": selected_user.get("username", _config.get("default_profile_name", "Perfil local")),
		"age": selected_user.get("age", 0),
		"email": selected_user.get("email", ""),
		"avatar_path": selected_user.get("avatar_path", ""),
		"created_at": selected_user.get("created_at", ""),
		"updated_at": selected_user.get("updated_at", "")
	})

	var migrated_progress: Variant = selected_user.get("progress", {})
	if migrated_progress is Dictionary:
		normalized["progress"] = migrated_progress

	normalized["save_meta"] = _normalize_save_meta.call({
		"last_saved_at": selected_user.get("updated_at", ""),
		"last_saved_reason": "legacy_migration",
		"write_count": 0
	})
	normalized["history"] = _normalize_history.call(selected_user.get("history", []))
	return normalized


func _resolve_selected_legacy_user(raw_data: Dictionary) -> Dictionary:
	var selected_user: Dictionary = {}
	var raw_users: Variant = raw_data.get("users", {})
	var last_user_key: String = str(raw_data.get("last_user", ""))
	if raw_users is Dictionary:
		if raw_users.has(last_user_key) and raw_users[last_user_key] is Dictionary:
			selected_user = raw_users[last_user_key]
		elif raw_users.size() > 0:
			var first_key: Variant = raw_users.keys()[0]
			if raw_users[first_key] is Dictionary:
				selected_user = raw_users[first_key]
	return selected_user