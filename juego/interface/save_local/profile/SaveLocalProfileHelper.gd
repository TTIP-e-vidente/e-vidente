extends RefCounted


static func normalizar_fecha_nacimiento(raw: Variant) -> String:
	if raw == null:
		return ""

	var clean := str(raw).strip_edges()
	if clean.is_empty():
		return ""

	if clean.length() >= 10 and clean[4] == "-" and clean[7] == "-":
		return clean.substr(0, 10)

	return ""


static func es_fecha_nacimiento_valida(birth_date: String) -> bool:
	var clean := birth_date.strip_edges()
	if clean.is_empty():
		return true
	if clean.length() != 10 or clean[4] != "-" or clean[7] != "-":
		return false

	var parts := clean.split("-", false)
	if parts.size() != 3:
		return false
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false

	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if year < 1900 or month < 1 or month > 12 or day < 1 or day > 31:
		return false

	var max_day := _dias_en_mes(year, month)
	if day > max_day:
		return false

	var today: Dictionary = Time.get_date_dict_from_system()
	var today_year: int = int(today.get("year", 0))
	var today_month: int = int(today.get("month", 0))
	var today_day: int = int(today.get("day", 0))
	var today_value := _fecha_a_valor(today_year, today_month, today_day)
	var birth_value := _fecha_a_valor(year, month, day)
	return birth_value <= today_value


static func calcular_edad_desde_fecha_nacimiento(birth_date: String) -> int:
	var clean := normalizar_fecha_nacimiento(birth_date)
	if clean.is_empty() or not es_fecha_nacimiento_valida(clean):
		return 0

	var parts := clean.split("-", false)
	var birth_year := int(parts[0])
	var birth_month := int(parts[1])
	var birth_day := int(parts[2])
	var today: Dictionary = Time.get_date_dict_from_system()
	var today_year: int = int(today.get("year", 0))
	var today_month: int = int(today.get("month", 0))
	var today_day: int = int(today.get("day", 0))
	var age: int = today_year - birth_year
	if today_month < birth_month or (today_month == birth_month and today_day < birth_day):
		age -= 1
	return maxi(0, age)


func validar_perfil(
	username: String,
	birth_date: String,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	var clean_username := username.strip_edges()
	var clean_email := email.strip_edges()
	var clean_avatar_path := avatar_source_path.strip_edges()
	var clean_birth_date := normalizar_fecha_nacimiento(birth_date)

	if not clean_username.is_empty() and clean_username.length() < 3:
		return {
			"ok": false,
			"message": "El nombre visible debe tener al menos 3 caracteres o quedar vacio."
		}
	if not es_fecha_nacimiento_valida(clean_birth_date):
		return {
			"ok": false,
			"message": "La fecha de nacimiento debe tener formato AAAA-MM-DD o quedar vacia."
		}
	if not clean_email.is_empty() and not es_email_valido(clean_email):
		return {"ok": false, "message": "Ingresa un mail valido o deja el campo vacio."}
	if not clean_avatar_path.is_empty() and cargar_textura_avatar(clean_avatar_path) == null:
		return {"ok": false, "message": "La foto seleccionada no se pudo abrir como imagen valida."}

	return {"ok": true}


func normalizar_datos_perfil(raw_profile: Dictionary, default_profile_name: String) -> Dictionary:
	var birth_date := normalizar_fecha_nacimiento(raw_profile.get("birth_date", ""))
	if birth_date.is_empty():
		birth_date = normalizar_fecha_nacimiento(
			raw_profile.get("fecha_nacimiento", raw_profile.get("birthDate", ""))
		)

	return {
		"username": str(raw_profile.get("username", default_profile_name)).strip_edges(),
		"birth_date": birth_date,
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
	birth_date: String,
	email: String,
	avatar_source_path: String
) -> Dictionary:
	return {
		"username": username.strip_edges(),
		"birth_date": normalizar_fecha_nacimiento(birth_date),
		"email": email.strip_edges(),
		"avatar_path": avatar_source_path.strip_edges()
	}


# Aplica los campos de identidad (nombre, fecha de nacimiento, mail) al perfil en-lugar.
func aplicar_cambios_identidad(
	profile: Dictionary,
	username: String,
	birth_date: String,
	email: String,
	default_profile_name: String
) -> void:
	var clean_username: String = username.strip_edges()
	profile["username"] = default_profile_name if clean_username.is_empty() else clean_username
	profile["birth_date"] = normalizar_fecha_nacimiento(birth_date)
	profile.erase("age")
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


static func _dias_en_mes(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0):
				return 29
			return 28
		_:
			return 0


static func _fecha_a_valor(year: int, month: int, day: int) -> int:
	return year * 10_000 + month * 100 + day
