@tool
extends Button

const BACKGROUND_TEXTURE_PATH := "res://assets-sistema/perfil/perfil-menu.png"
const BUTTON_MIN_SIZE := Vector2(220.0, 68.0)
const BACKGROUND_MARGIN := 6.0
const AVATAR_SCALE_IN_LEFT_TILE := 0.64

var _background_sprite: Sprite2D = null
var _avatar_sprite: Sprite2D = null
var _sync_badge: Label = null


func _ready() -> void:
	flat = true
	text = ""
	icon = null
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_aplicar_sobrescrituras_estilo_vacio()
	_asegurar_nodos_visuales()
	refrescar_icono_perfil()


func _get_minimum_size() -> Vector2:
	return BUTTON_MIN_SIZE


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_RESIZED
		or what == NOTIFICATION_THEME_CHANGED
		or what == NOTIFICATION_FOCUS_ENTER
		or what == NOTIFICATION_FOCUS_EXIT
	):
		_distribuir_nodos_visuales()


func refrescar_icono_perfil() -> void:
	_asegurar_nodos_visuales()
	_refrescar_textura_avatar()
	_actualizar_badge_sync()
	_distribuir_nodos_visuales()


func _asegurar_nodos_visuales() -> void:
	var can_create_nodes: bool = not Engine.is_editor_hint()
	var legacy_sprite: Sprite2D = get_node_or_null("Perfil") as Sprite2D
	if legacy_sprite != null:
		legacy_sprite.visible = false

	if _background_sprite == null or not is_instance_valid(_background_sprite):
		_background_sprite = get_node_or_null("ProfileBackground") as Sprite2D
		if _background_sprite == null and can_create_nodes:
			_background_sprite = Sprite2D.new()
			_background_sprite.name = "ProfileBackground"
			add_child(_background_sprite)
	if _background_sprite != null:
		_background_sprite.centered = true
		_background_sprite.z_index = 0
		_background_sprite.texture = load(BACKGROUND_TEXTURE_PATH) as Texture2D

	if _avatar_sprite == null or not is_instance_valid(_avatar_sprite):
		_avatar_sprite = get_node_or_null("AvatarPreview") as Sprite2D
		if _avatar_sprite == null and can_create_nodes:
			_avatar_sprite = Sprite2D.new()
			_avatar_sprite.name = "AvatarPreview"
			add_child(_avatar_sprite)
	if _avatar_sprite != null:
		_avatar_sprite.centered = true
		_avatar_sprite.z_index = 1


func _refrescar_textura_avatar() -> void:
	if _avatar_sprite == null:
		return
	if Engine.is_editor_hint():
		_avatar_sprite.texture = null
		_avatar_sprite.visible = false
		return
	var avatar_texture: Texture2D = null
	if SaveManager != null and SaveManager.has_method("obtener_textura_avatar_usuario_actual"):
		avatar_texture = SaveManager.obtener_textura_avatar_usuario_actual()
	_avatar_sprite.texture = avatar_texture
	_avatar_sprite.visible = avatar_texture != null



func _distribuir_nodos_visuales() -> void:
	if not is_node_ready() or _background_sprite == null or _background_sprite.texture == null:
		return

	var texture_size: Vector2 = _background_sprite.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var available_width: float = maxf(1.0, size.x - BACKGROUND_MARGIN)
	var available_height: float = maxf(1.0, size.y - BACKGROUND_MARGIN)

	var scale_factor: float = minf(
		available_width / texture_size.x,
		available_height / texture_size.y
	)

	var scaled_size: Vector2 = texture_size * scale_factor

	_background_sprite.scale = Vector2.ONE * scale_factor
	_background_sprite.position = Vector2(
		size.x - BACKGROUND_MARGIN - scaled_size.x * 0.5,
		size.y * 0.5
	)

	if _avatar_sprite == null or not _avatar_sprite.visible or _avatar_sprite.texture == null:
		return

	var avatar_texture_size: Vector2 = _avatar_sprite.texture.get_size()
	if avatar_texture_size.x <= 0.0 or avatar_texture_size.y <= 0.0:
		return

	# -------------------------------------------------------
	# Recorte cuadrado centrado del avatar
	# -------------------------------------------------------
	var side := minf(avatar_texture_size.x, avatar_texture_size.y)

	_avatar_sprite.region_enabled = true
	_avatar_sprite.region_rect = Rect2(
		(avatar_texture_size.x - side) * 0.5,
		(avatar_texture_size.y - side) * 0.5,
		side,
		side
	)

	# -------------------------------------------------------
	# Escala del cuadrado del avatar
	# -------------------------------------------------------
	var left_tile_size: float = scaled_size.y
	var avatar_target_size: float = left_tile_size * AVATAR_SCALE_IN_LEFT_TILE + 6.0

	var avatar_scale: float = avatar_target_size / side

	_avatar_sprite.scale = Vector2.ONE * avatar_scale

	var background_top_left: Vector2 = _background_sprite.position - scaled_size * 0.5

	_avatar_sprite.position = background_top_left + Vector2(
		left_tile_size * 0.5,
		scaled_size.y * 0.5
	)

	_posicionar_badge_sync()


func _asegurar_sync_badge() -> void:
	if Engine.is_editor_hint():
		return
	if _sync_badge != null and is_instance_valid(_sync_badge):
		return
	_sync_badge = Label.new()
	_sync_badge.name = "SyncPendingBadge"
	_sync_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sync_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sync_badge.custom_minimum_size = Vector2(22.0, 22.0)
	_sync_badge.add_theme_font_size_override("font_size", 12)
	_sync_badge.add_theme_color_override("font_color", Color.WHITE)
	_sync_badge.z_index = 2
	add_child(_sync_badge)


func _actualizar_badge_sync() -> void:
	_asegurar_sync_badge()
	if _sync_badge == null:
		return
	if Engine.is_editor_hint():
		_sync_badge.visible = false
		return
	var pending := 0
	if AuthApi.esta_logueado():
		pending = LocalSyncQueue.contar_pendientes()
	_sync_badge.visible = pending > 0
	if pending > 0:
		_sync_badge.text = "9+" if pending >= 10 else str(pending)


func _posicionar_badge_sync() -> void:
	if _sync_badge == null or not _sync_badge.visible:
		return
	_sync_badge.position = Vector2(size.x - 18.0, 6.0)


func _aplicar_sobrescrituras_estilo_vacio() -> void:
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_style)
	add_theme_stylebox_override("hover", empty_style)
	add_theme_stylebox_override("pressed", empty_style)
	add_theme_stylebox_override("focus", empty_style)
	add_theme_stylebox_override("disabled", empty_style)
