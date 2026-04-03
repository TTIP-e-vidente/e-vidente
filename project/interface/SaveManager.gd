extends Node

signal user_registered(profile: Dictionary)
signal user_logged_in(profile: Dictionary)
signal user_logged_out()
signal progress_saved(profile: Dictionary)
signal progress_loaded(profile: Dictionary)

const SAVE_PATH := "user://save_data.json"
const AVATARS_DIR := "user://avatars"
const SAVE_VERSION := 1
const HISTORY_LIMIT := 25

var save_data: Dictionary = {}
var current_user_key := ""


func _ready() -> void:
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_user_progress()


func load_data() -> void:
	save_data = _default_save_data()
	if not FileAccess.file_exists(SAVE_PATH):
		_write_save_data()
		return

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		return

	var parsed_data = JSON.parse_string(save_file.get_as_text())
	if parsed_data is Dictionary:
		save_data = _normalize_save_data(parsed_data)
	else:
		_write_save_data()


func is_authenticated() -> bool:
	return not current_user_key.is_empty() and save_data["users"].has(current_user_key)


func has_accounts() -> bool:
	return get_users_count() > 0


func get_users_count() -> int:
	return save_data.get("users", {}).size()


func get_last_user_hint() -> String:
	var last_user_key := str(save_data.get("last_user", ""))
	if last_user_key.is_empty():
		return ""
	var user := save_data["users"].get(last_user_key, {})
	return str(user.get("username", ""))


func register_user(username: String, password: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	var validation := _validate_registration(username, password, age, email, avatar_source_path)
	if not validation["ok"]:
		return validation

	var user_key := _normalize_username_key(username)
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var avatar_path := _persist_avatar(user_key, avatar_source_path)
	var user_record := {
		"username": username.strip_edges(),
		"password_hash": _hash_password(password),
		"age": age,
		"email": email.strip_edges(),
		"email_key": _normalize_email_key(email),
		"avatar_path": avatar_path,
		"created_at": timestamp,
		"updated_at": timestamp,
		"progress": {},
		"history": []
	}

	save_data["users"][user_key] = user_record
	save_data["last_user"] = user_key
	current_user_key = user_key
	Global.reset_progress()
	save_current_user_progress(false)
	_append_history(current_user_key, "Cuenta creada", {"type": "register"})
	_write_save_data()

	var profile := get_current_user_profile()
	user_registered.emit(profile)
	user_logged_in.emit(profile)
	progress_loaded.emit(profile)
	return {"ok": true, "message": "Cuenta creada. Ya podes entrar al Archivero.", "profile": profile}


func login_user(identifier: String, password: String) -> Dictionary:
	var user_key := _find_user_key(identifier)
	if user_key.is_empty():
		return {"ok": false, "message": "No existe una cuenta local con ese usuario o mail."}

	var user_record: Dictionary = save_data["users"][user_key]
	if user_record.get("password_hash", "") != _hash_password(password):
		return {"ok": false, "message": "La contrasena no coincide con la cuenta local guardada."}

	current_user_key = user_key
	save_data["last_user"] = user_key
	load_current_user_progress(false)
	_append_history(user_key, "Inicio de sesion", {"type": "login"})
	_write_save_data()

	var profile := get_current_user_profile()
	user_logged_in.emit(profile)
	return {"ok": true, "message": "Sesion iniciada. Cargando progreso local.", "profile": profile}


func logout() -> void:
	if not is_authenticated():
		Global.reset_progress()
		current_user_key = ""
		return

	var last_key := current_user_key
	save_current_user_progress(false)
	_append_history(last_key, "Sesion cerrada", {"type": "logout"})
	current_user_key = ""
	Global.reset_progress()
	_write_save_data()
	user_logged_out.emit()


func save_current_user_progress(write_to_disk: bool = true) -> void:
	if not is_authenticated():
		return

	var user_record: Dictionary = save_data["users"][current_user_key]
	user_record["progress"] = Global.export_progress()
	user_record["updated_at"] = Time.get_datetime_string_from_system(false, true)
	save_data["users"][current_user_key] = user_record

	if write_to_disk:
		_write_save_data()
		progress_saved.emit(get_current_user_profile())


func load_current_user_progress(emit_signal: bool = true) -> void:
	if not is_authenticated():
		Global.reset_progress()
		return

	var user_record: Dictionary = save_data["users"][current_user_key]
	Global.import_progress(user_record.get("progress", {}))
	if emit_signal:
		progress_loaded.emit(get_current_user_profile())


func record_level_completed(track_key: String, level_number: int) -> void:
	if not is_authenticated():
		return

	save_current_user_progress(false)
	var message := "Completaste %s - capitulo %d" % [_track_label(track_key), level_number]
	_append_history(current_user_key, message, {
		"type": "level_completed",
		"track": track_key,
		"level": level_number
	})
	_write_save_data()
	progress_saved.emit(get_current_user_profile())


func record_manual_save() -> void:
	if not is_authenticated():
		return

	save_current_user_progress(false)
	_append_history(current_user_key, "Guardado manual", {"type": "manual_save"})
	_write_save_data()
	progress_saved.emit(get_current_user_profile())


func get_current_user_profile() -> Dictionary:
	if not is_authenticated():
		return {}

	var user_record: Dictionary = save_data["users"][current_user_key]
	return {
		"username": user_record.get("username", ""),
		"age": int(user_record.get("age", 0)),
		"email": user_record.get("email", ""),
		"avatar_path": user_record.get("avatar_path", ""),
		"created_at": user_record.get("created_at", ""),
		"updated_at": user_record.get("updated_at", "")
	}


func get_current_user_history() -> Array:
	if not is_authenticated():
		return []

	var history = save_data["users"][current_user_key].get("history", [])
	return history.duplicate(true)


func load_avatar_texture(path: String) -> Texture2D:
	var avatar_path := path.strip_edges()
	if avatar_path.is_empty():
		return null

	var image := Image.new()
	var error := image.load(avatar_path)
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


func get_current_user_avatar_texture() -> Texture2D:
	var profile := get_current_user_profile()
	if profile.is_empty():
		return null
	return load_avatar_texture(str(profile.get("avatar_path", "")))


func _validate_registration(username: String, password: String, age: int, email: String, avatar_source_path: String) -> Dictionary:
	var clean_username := username.strip_edges()
	var clean_email := email.strip_edges()
	var clean_avatar_path := avatar_source_path.strip_edges()

	if clean_username.length() < 3:
		return {"ok": false, "message": "El nombre de usuario debe tener al menos 3 caracteres."}
	if password.length() < 8:
		return {"ok": false, "message": "La contrasena debe tener al menos 8 caracteres."}
	if age < 1:
		return {"ok": false, "message": "La edad debe ser mayor a 0."}
	if not _is_valid_email(clean_email):
		return {"ok": false, "message": "Ingresa un mail valido para registrar la cuenta."}
	if clean_avatar_path.is_empty():
		return {"ok": false, "message": "Selecciona un avatar o foto para guardar el perfil local."}
	if load_avatar_texture(clean_avatar_path) == null:
		return {"ok": false, "message": "La foto seleccionada no se pudo abrir como imagen valida."}

	var user_key := _normalize_username_key(clean_username)
	if save_data["users"].has(user_key):
		return {"ok": false, "message": "Ya existe un usuario local con ese nombre."}
	if _email_exists(clean_email):
		return {"ok": false, "message": "Ese mail ya esta asociado a otra cuenta local."}

	return {"ok": true}


func _default_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"last_user": "",
		"users": {}
	}


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized := _default_save_data()
	normalized["version"] = int(raw_data.get("version", SAVE_VERSION))
	normalized["last_user"] = str(raw_data.get("last_user", ""))

	var raw_users = raw_data.get("users", {})
	if raw_users is Dictionary:
		for user_key in raw_users.keys():
			var raw_user = raw_users[user_key]
			if raw_user is Dictionary:
				normalized["users"][str(user_key)] = {
					"username": str(raw_user.get("username", "")),
					"password_hash": str(raw_user.get("password_hash", "")),
					"age": int(raw_user.get("age", 0)),
					"email": str(raw_user.get("email", "")),
					"email_key": str(raw_user.get("email_key", "")).to_lower(),
					"avatar_path": str(raw_user.get("avatar_path", "")),
					"created_at": str(raw_user.get("created_at", "")),
					"updated_at": str(raw_user.get("updated_at", "")),
					"progress": raw_user.get("progress", {}),
					"history": _normalize_history(raw_user.get("history", []))
				}

	if not normalized["users"].has(normalized["last_user"]):
		normalized["last_user"] = ""

	return normalized


func _normalize_history(raw_history: Variant) -> Array:
	var history: Array = []
	if raw_history is Array:
		for entry in raw_history:
			if entry is Dictionary:
				history.append(entry)
	return history


func _write_save_data() -> void:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		return
	save_file.store_string(JSON.stringify(save_data, "\t"))


func _append_history(user_key: String, message: String, metadata: Dictionary = {}) -> void:
	if not save_data["users"].has(user_key):
		return

	var user_record: Dictionary = save_data["users"][user_key]
	var history: Array = user_record.get("history", [])
	history.push_front({
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"message": message,
		"metadata": metadata
	})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(0, HISTORY_LIMIT)
	user_record["history"] = history
	user_record["updated_at"] = Time.get_datetime_string_from_system(false, true)
	save_data["users"][user_key] = user_record


func _persist_avatar(user_key: String, source_path: String) -> String:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty():
		return ""

	var avatars_dir_absolute := ProjectSettings.globalize_path(AVATARS_DIR)
	DirAccess.make_dir_recursive_absolute(avatars_dir_absolute)

	var extension := clean_source.get_extension().to_lower()
	if extension.is_empty():
		extension = "png"

	var destination := "%s/%s.%s" % [AVATARS_DIR, _safe_file_key(user_key), extension]
	var source_file := FileAccess.open(clean_source, FileAccess.READ)
	if source_file == null:
		return clean_source

	var buffer := source_file.get_buffer(source_file.get_length())
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	if destination_file == null:
		return clean_source
	destination_file.store_buffer(buffer)
	return destination


func _find_user_key(identifier: String) -> String:
	var clean_identifier := identifier.strip_edges()
	if clean_identifier.is_empty():
		return ""

	var username_key := _normalize_username_key(clean_identifier)
	if save_data["users"].has(username_key):
		return username_key

	var email_key := _normalize_email_key(clean_identifier)
	for user_key in save_data["users"].keys():
		var user_record: Dictionary = save_data["users"][user_key]
		if user_record.get("email_key", "") == email_key:
			return str(user_key)

	return ""


func _email_exists(email: String) -> bool:
	var email_key := _normalize_email_key(email)
	for user_record in save_data["users"].values():
		if user_record.get("email_key", "") == email_key:
			return true
	return false


func _normalize_username_key(username: String) -> String:
	return username.strip_edges().to_lower()


func _normalize_email_key(email: String) -> String:
	return email.strip_edges().to_lower()


func _safe_file_key(raw_key: String) -> String:
	var safe_key := raw_key.to_lower().strip_edges()
	for character in [" ", "/", "\\", ":", ".", ",", ";", "\"", "'", "?", "!", "@", "#", "$", "%", "&", "(", ")", "[", "]", "{", "}"]:
		safe_key = safe_key.replace(character, "_")
	return safe_key


func _hash_password(password: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(password.to_utf8_buffer())
	return hashing.finish().hex_encode()


func _is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return regex.search(email) != null


func _track_label(track_key: String) -> String:
	match track_key:
		"celiaquia":
			return "Celiaquia"
		"veganismo":
			return "Veganismo"
		"veganismo_celiaquia":
			return "Veganismo + Celiaquia"
		_:
			return "Tu progreso"