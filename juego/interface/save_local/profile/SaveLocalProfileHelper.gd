extends RefCounted


func validar_perfil(
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
	if not clean_email.is_empty() and not es_email_valido(clean_email):
		return {"ok": false, "message": "Ingresa un mail valido o deja el campo vacio."}
	if not clean_avatar_path.is_empty() and cargar_textura_avatar(clean_avatar_path) == null:
		return {"ok": false, "message": "La foto seleccionada no se pudo abrir como imagen valida."}

	return {"ok": true}


func normalizar_datos_perfil(raw_profile: Dictionary, default_profile_name: String) -> Dictionary:
	return {
		"username": str(raw_profile.get("username", default_profile_name)).strip_edges(),
		"age": max(0, int(raw_profile.get("age", 0))),
		"email": str(raw_profile.get("email", "")).strip_edges(),
		"avatar_path": str(raw_profile.get("avatar_path", "")).strip_edges(),
		"created_at": str(raw_profile.get("created_at", "")),
		"updated_at": str(raw_profile.get("updated_at", ""))
	}


func cargar_textura_avatar(path: String) -> Texture2D:
	var avatar_path := path.strip_edges()
	if avatar_path.is_empty():
		return null

	var image := Image.new()
	var error := image.load(avatar_path)
	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


func persistir_avatar(avatars_dir: String, user_key: String, source_path: String) -> String:
	var clean_source := source_path.strip_edges()
	if clean_source.is_empty():
		return ""

	var avatars_dir_absolute := ProjectSettings.globalize_path(avatars_dir)
	DirAccess.make_dir_recursive_absolute(avatars_dir_absolute)

	var extension := clean_source.get_extension().to_lower()
	if extension.is_empty():
		extension = "png"

	var destination := "%s/%s.%s" % [avatars_dir, clave_archivo_segura(user_key), extension]
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


func eliminar_avatar_gestionado(avatars_dir: String, path: String) -> void:
	var clean_path := path.strip_edges()
	if clean_path.is_empty():
		return
	if not clean_path.begins_with("%s/" % avatars_dir):
		return
	eliminar_archivo_si_existe(clean_path)


func clave_archivo_segura(raw_key: String) -> String:
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


func es_email_valido(email: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return regex.search(email) != null


func eliminar_archivo_si_existe(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# Construye un diccionario limpio con los campos del perfil normalizados.
func construir_actualizacion_limpia(
	username: String,
	age: int,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return {
		"username": username.strip_edges(),
		"age": max(0, age),
		"email": email.strip_edges(),
		"avatar_path": avatar_source_path.strip_edges()
	}


# Aplica los campos de identidad (nombre, edad, mail) al diccionario de perfil en-lugar.
func aplicar_cambios_identidad(
	profile: Dictionary,
	username: String,
	age: int,
	email: String,
	default_profile_name: String
) -> void:
	var clean_username: String = username.strip_edges()
	profile["username"] = default_profile_name if clean_username.is_empty() else clean_username
	profile["age"] = max(0, age)
	profile["email"] = email.strip_edges()


# Copia y persiste el avatar nuevo si cambió. Elimina el avatar anterior si ya no se usa.
func aplicar_cambio_avatar(
	profile: Dictionary,
	clean_avatar_path: String,
	previous_avatar_path: String,
	avatars_dir: String,
	profile_key: String
) -> Dictionary:
	if clean_avatar_path.is_empty():
		eliminar_avatar_gestionado(avatars_dir, previous_avatar_path)
		profile["avatar_path"] = ""
		return {"ok": true}

	var persisted_path: String = persistir_avatar(avatars_dir, profile_key, clean_avatar_path)
	if persisted_path.is_empty():
		return {
			"ok": false,
			"message": "No se pudo copiar la foto seleccionada al almacenamiento local."
		}

	if persisted_path != previous_avatar_path:
		eliminar_avatar_gestionado(avatars_dir, previous_avatar_path)
	profile["avatar_path"] = persisted_path
	return {"ok": true}


# Estampa created_at y updated_at en el perfil. Crea created_at si no existe.
func estampar_timestamps(profile: Dictionary) -> void:
	var timestamp: String = Time.get_datetime_string_from_system(false, true)
	profile["updated_at"] = timestamp
	if str(profile.get("created_at", "")).is_empty():
		profile["created_at"] = timestamp