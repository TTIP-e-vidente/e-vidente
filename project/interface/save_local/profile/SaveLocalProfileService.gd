extends RefCounted

var _manager


func _init(manager):
	_manager = manager


func update_local_profile(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var validation: Dictionary = validate_profile(username, age, email, avatar_source_path)
	if not bool(validation.get("ok", false)):
		return validation

	var clean_username: String = username.strip_edges()
	var clean_email: String = email.strip_edges()
	var clean_avatar_path: String = avatar_source_path.strip_edges()
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	var profile: Dictionary = get_current_user_profile()
	var previous_avatar_path: String = str(profile.get("avatar_path", "")).strip_edges()

	if clean_username.is_empty():
		profile["username"] = _manager.DEFAULT_PROFILE_NAME
	else:
		profile["username"] = clean_username
	profile["age"] = max(0, age)
	profile["email"] = clean_email
	if clean_avatar_path.is_empty():
		_profile_helper().remove_managed_avatar(_manager.AVATARS_DIR, previous_avatar_path)
		profile["avatar_path"] = ""
	else:
		var persisted_avatar_path: String = _profile_helper().persist_avatar(
			_manager.AVATARS_DIR,
			_manager.current_user_key,
			clean_avatar_path
		)
		if persisted_avatar_path.is_empty():
			return {
				"ok": false,
				"message": "No se pudo copiar la foto seleccionada al almacenamiento local."
			}
		if persisted_avatar_path != previous_avatar_path:
			_profile_helper().remove_managed_avatar(
				_manager.AVATARS_DIR,
				previous_avatar_path
			)
		profile["avatar_path"] = persisted_avatar_path
	profile["updated_at"] = timestamp
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = timestamp

	_manager.save_data["profile"] = profile
	_write_coordinator().mark_dirty()
	_resume_service().append_history("Perfil local actualizado", {"type": "profile_updated"})
	_manager.sync_runtime_progress_to_current_save()
	if not _write_coordinator().write_save_data(false, "profile_updated"):
		return {"ok": false, "message": "No se pudo escribir el perfil local en disco."}

	var updated_profile: Dictionary = get_current_user_profile()
	_manager.user_registered.emit(updated_profile)
	_manager.user_logged_in.emit(updated_profile)
	_manager.progress_loaded.emit(updated_profile)
	return {"ok": true, "message": "Perfil local actualizado.", "profile": updated_profile}


func get_current_user_profile() -> Dictionary:
	var user_record = _manager.save_data.get("profile", {})
	if not user_record is Dictionary:
		return {}
	return {
		"username": user_record.get("username", _manager.DEFAULT_PROFILE_NAME),
		"age": int(user_record.get("age", 0)),
		"email": user_record.get("email", ""),
		"avatar_path": user_record.get("avatar_path", ""),
		"created_at": user_record.get("created_at", ""),
		"updated_at": user_record.get("updated_at", "")
	}


func load_avatar_texture(path: String) -> Texture2D:
	return _profile_helper().load_avatar_texture(path)


func get_current_user_avatar_texture() -> Texture2D:
	var profile: Dictionary = get_current_user_profile()
	if profile.is_empty():
		return null
	return load_avatar_texture(str(profile.get("avatar_path", "")))


func validate_profile(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return _profile_helper().validate_profile(
		username,
		age,
		email,
		avatar_source_path
	)


func ensure_local_profile() -> bool:
	var changed := false
	var profile: Variant = _manager.save_data.get("profile", {})
	if not profile is Dictionary:
		profile = {}
		changed = true

	profile = _data_normalizer().normalize_profile_data(profile)
	if str(profile.get("username", "")).is_empty():
		profile["username"] = _manager.DEFAULT_PROFILE_NAME
		changed = true

	var created_at: String = str(profile.get("created_at", ""))
	if created_at.is_empty():
		created_at = Time.get_datetime_string_from_system(false, true)
		profile["created_at"] = created_at
		changed = true

	if str(profile.get("updated_at", "")).is_empty():
		profile["updated_at"] = created_at
		changed = true

	if not _manager.save_data.get("progress", {}) is Dictionary:
		_manager.save_data["progress"] = {}
		changed = true

	if not _manager.save_data.get("history", []) is Array:
		_manager.save_data["history"] = []
		changed = true

	var save_meta: Variant = _manager.save_data.get("save_meta", {})
	if not save_meta is Dictionary:
		_manager.save_data["save_meta"] = _data_normalizer().default_save_meta()
		changed = true
	else:
		_manager.save_data["save_meta"] = _data_normalizer().normalize_save_meta(save_meta)

	var resume_state: Variant = _manager.save_data.get("resume_state", {})
	if not resume_state is Dictionary:
		_manager.save_data["resume_state"] = _data_normalizer().default_resume_state()
		changed = true
	else:
		_manager.save_data["resume_state"] = _data_normalizer().normalize_resume_state(resume_state)

	_manager.save_data["profile"] = profile
	_manager.current_user_key = "local_profile"
	if changed:
		_write_coordinator().mark_dirty()
	return changed


func _resume_service():
	return _manager.get_resume_service()


func _write_coordinator():
	return _manager.get_write_coordinator()


func _data_normalizer():
	return _manager.get_save_data_normalizer()


func _profile_helper():
	return _manager.get_profile_data_helper()
