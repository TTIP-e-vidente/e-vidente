extends RefCounted


func validate_profile(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var clean_username := username.strip_edges()
	var clean_email := email.strip_edges()
	var clean_avatar_path := avatar_source_path.strip_edges()

	if not clean_username.is_empty() and clean_username.length() < 3:
		return {
			"ok": false,
			"message": "El nombre visible debe tener al menos 3 caracteres o quedar vacio."
		}
	if age < 0:
		return {"ok": false, "message": "La edad no puede ser negativa."}
	if not clean_email.is_empty() and not is_valid_email(clean_email):
		return {"ok": false, "message": "Ingresa un mail valido o deja el campo vacio."}
	if not clean_avatar_path.is_empty() and load_avatar_texture(clean_avatar_path) == null:
		return {"ok": false, "message": "La foto seleccionada no se pudo abrir como imagen valida."}

	return {"ok": true}


func normalize_profile_data(raw_profile: Dictionary, default_profile_name: String) -> Dictionary:
	return {
		"username": str(raw_profile.get("username", default_profile_name)).strip_edges(),
		"age": max(0, int(raw_profile.get("age", 0))),
		"email": str(raw_profile.get("email", "")).strip_edges(),
		"avatar_path": str(raw_profile.get("avatar_path", "")).strip_edges(),
		"created_at": str(raw_profile.get("created_at", "")),
		"updated_at": str(raw_profile.get("updated_at", ""))
	}


func load_avatar_texture(path: String) -> Texture2D:
	var avatar_path := path.strip_edges()
	if avatar_path.is_empty():
		return null

	var image := Image.new()
	var error := image.load(avatar_path)
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


func persist_avatar(avatars_dir: String, user_key: String, source_path: String) -> String:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty():
		return ""

	var avatars_dir_absolute := ProjectSettings.globalize_path(avatars_dir)
	DirAccess.make_dir_recursive_absolute(avatars_dir_absolute)

	var extension := clean_source.get_extension().to_lower()
	if extension.is_empty():
		extension = "png"

	var destination := "%s/%s.%s" % [avatars_dir, safe_file_key(user_key), extension]
	var source_file := FileAccess.open(clean_source, FileAccess.READ)
	if source_file == null:
		return ""

	var buffer := source_file.get_buffer(source_file.get_length())
	source_file = null
	var destination_file := FileAccess.open(destination, FileAccess.WRITE)
	if destination_file == null:
		return ""
	destination_file.store_buffer(buffer)
	destination_file.flush()
	destination_file = null
	return destination


func remove_managed_avatar(avatars_dir: String, path: String) -> void:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return
	if not clean_path.begins_with("%s/" % avatars_dir):
		return
	remove_file_if_exists(clean_path)


func safe_file_key(raw_key: String) -> String:
	var safe_key := raw_key.to_lower().strip_edges()
	for character in [
		" ",
		"/",
		"\\",
		":",
		".",
		",",
		";",
		"\"",
		"'",
		"?",
		"!",
		"@",
		"#",
		"$",
		"%",
		"&",
		"(",
		")",
		"[",
		"]",
		"{",
		"}"
	]:
		safe_key = safe_key.replace(character, "_")
	return safe_key


func is_valid_email(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return regex.search(email) != null


func remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))